# cred.ps1 <read|write|delete> [file]
# Raw access to agy's login in Windows Credential Manager. Used by agyr (through cred.sh) on Windows.
#   read FILE    write the entry's blob to FILE (exact bytes)
#   write FILE   store the bytes of FILE as the entry's blob (replaces the entry)
#   delete       remove the entry
# Exit codes: 0 ok | 3 no such entry | 1 any other error | 2 bad usage. Never prints the blob.
# Environment: AGY_CRED_TARGET (default gemini:antigravity), AGY_CRED_USER (default antigravity)
#
# The entry agy creates is: type 1 (generic), persist 2 (local machine), user "antigravity", blob = UTF-8 JSON
# (about 1.6 KB; Windows allows at most 2560 bytes). 'write' recreates exactly that shape.
param(
  [Parameter(Mandatory = $true, Position = 0)][ValidateSet('read', 'write', 'delete')][string]$Op,
  [Parameter(Position = 1)][string]$File
)
$ErrorActionPreference = 'Stop'
$target = if ($env:AGY_CRED_TARGET) { $env:AGY_CRED_TARGET } else { 'gemini:antigravity' }
$user = if ($env:AGY_CRED_USER) { $env:AGY_CRED_USER } else { 'antigravity' }

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WinCred {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  struct CREDENTIAL {
    public uint Flags;
    public uint Type;
    public string TargetName;
    public string Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public uint CredentialBlobSize;
    public IntPtr CredentialBlob;
    public uint Persist;
    public uint AttributeCount;
    public IntPtr Attributes;
    public string TargetAlias;
    public string UserName;
  }
  [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
  static extern bool CredRead(string target, uint type, uint flags, out IntPtr cred);
  [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
  static extern bool CredWrite(ref CREDENTIAL cred, uint flags);
  [DllImport("advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode, SetLastError = true)]
  static extern bool CredDelete(string target, uint type, uint flags);
  [DllImport("advapi32.dll")]
  static extern void CredFree(IntPtr buffer);

  // returns the blob, or null with err set to the Win32 error code
  public static byte[] Read(string target, out int err) {
    err = 0;
    IntPtr p;
    if (!CredRead(target, 1, 0, out p)) { err = Marshal.GetLastWin32Error(); return null; }
    try {
      CREDENTIAL c = (CREDENTIAL)Marshal.PtrToStructure(p, typeof(CREDENTIAL));
      byte[] blob = new byte[c.CredentialBlobSize];
      if (blob.Length > 0) Marshal.Copy(c.CredentialBlob, blob, 0, blob.Length);
      return blob;
    } finally { CredFree(p); }
  }

  public static int Write(string target, string user, byte[] blob) {
    IntPtr mem = Marshal.AllocHGlobal(blob.Length);
    try {
      Marshal.Copy(blob, 0, mem, blob.Length);
      CREDENTIAL c = new CREDENTIAL();
      c.Type = 1;
      c.TargetName = target;
      c.UserName = user;
      c.Persist = 2;
      c.CredentialBlobSize = (uint)blob.Length;
      c.CredentialBlob = mem;
      return CredWrite(ref c, 0) ? 0 : Marshal.GetLastWin32Error();
    } finally { Marshal.FreeHGlobal(mem); }
  }

  public static int Delete(string target) {
    return CredDelete(target, 1, 0) ? 0 : Marshal.GetLastWin32Error();
  }
}
'@

function Fail($msg, $code) { [Console]::Error.WriteLine("agyr-cred: $msg"); exit $code }
$ERROR_NOT_FOUND = 1168

if ($Op -ne 'delete') {
  if (-not $File) { Fail "usage: cred.ps1 $Op FILE" 2 }
  $File = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($File)
}

switch ($Op) {
  'read' {
    $err = 0
    $blob = [WinCred]::Read($target, [ref]$err)
    if ($null -eq $blob) {
      if ($err -eq $ERROR_NOT_FOUND) { exit 3 }
      Fail "CredRead failed (win32 error $err)" 1
    }
    [IO.File]::WriteAllBytes($File, $blob)
  }
  'write' {
    $blob = [IO.File]::ReadAllBytes($File)
    if ($blob.Length -eq 0) { Fail 'refusing to store an empty login' 1 }
    if ($blob.Length -gt 2560) { Fail "login is $($blob.Length) bytes; Credential Manager allows at most 2560" 1 }
    $err = [WinCred]::Write($target, $user, $blob)
    if ($err -ne 0) { Fail "CredWrite failed (win32 error $err)" 1 }
  }
  'delete' {
    $err = [WinCred]::Delete($target)
    if ($err -eq $ERROR_NOT_FOUND) { exit 3 }
    if ($err -ne 0) { Fail "CredDelete failed (win32 error $err)" 1 }
  }
}
exit 0
