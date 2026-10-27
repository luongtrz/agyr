# Prints METADATA ONLY about Windows Credential Manager entries whose target looks like agy's login
# (target name matches gemini|antigravity|agy). It never prints a secret value: only target name, type, persist scope,
# user name, blob size, encoding guess, and the JSON key structure (key names, value types, string lengths).
# Entries whose target does not match are not printed at all.
#
# Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File windows\inspect-cred.ps1
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CredEnum {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct CREDENTIAL {
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
  [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern bool CredEnumerateW(string filter, uint flags, out uint count, out IntPtr credentials);
  [DllImport("advapi32.dll")]
  public static extern void CredFree(IntPtr buffer);
}
'@

function Show-Shape($o, $indent) {
  if ($o -is [System.Management.Automation.PSCustomObject]) {
    foreach ($p in $o.PSObject.Properties) {
      $v = $p.Value
      if ($v -is [string]) { "{0}{1}: string (length {2})" -f $indent, $p.Name, $v.Length }
      elseif ($null -eq $v) { "{0}{1}: null" -f $indent, $p.Name }
      elseif ($v -is [System.Management.Automation.PSCustomObject]) { "{0}{1}: object" -f $indent, $p.Name; Show-Shape $v ($indent + '  ') }
      else { "{0}{1}: {2}" -f $indent, $p.Name, $v.GetType().Name }
    }
  }
}

$count = [uint32]0
$ptr = [IntPtr]::Zero
if (-not [CredEnum]::CredEnumerateW('*', 0, [ref]$count, [ref]$ptr)) {
  Write-Output "CredEnumerate failed or no credentials (win32 error $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))"
  exit 1
}
$found = 0
try {
  for ($i = 0; $i -lt $count; $i++) {
    $p = [Runtime.InteropServices.Marshal]::ReadIntPtr($ptr, $i * [IntPtr]::Size)
    $c = [Runtime.InteropServices.Marshal]::PtrToStructure($p, [Type][CredEnum+CREDENTIAL])
    if ($c.TargetName -notmatch '(?i)gemini|antigravity|agy') { continue }
    $found++
    $n = [int]$c.CredentialBlobSize
    $bytes = New-Object byte[] $n
    if ($n -gt 0) { [Runtime.InteropServices.Marshal]::Copy($c.CredentialBlob, $bytes, 0, $n) }
    $enc = 'utf-8'
    if ($n -ge 2 -and $bytes[1] -eq 0 -and $bytes[0] -ne 0) { $enc = 'utf-16le' }
    $text = if ($enc -eq 'utf-16le') { [Text.Encoding]::Unicode.GetString($bytes) } else { [Text.Encoding]::UTF8.GetString($bytes) }
    Write-Output "--- entry $found"
    Write-Output ("TargetName : {0}" -f $c.TargetName)
    Write-Output ("Type       : {0}   (1 = generic)" -f $c.Type)
    Write-Output ("Persist    : {0}   (1 = session, 2 = local machine, 3 = enterprise)" -f $c.Persist)
    Write-Output ("UserName   : {0}" -f $c.UserName)
    Write-Output ("Flags      : {0}   Comment length: {1}   Attributes: {2}" -f $c.Flags, ($(if ($c.Comment) { $c.Comment.Length } else { 0 })), $c.AttributeCount)
    Write-Output ("BlobSize   : {0} bytes (Windows limit is 2560)   encoding guess: {1}" -f $n, $enc)
    try {
      $j = $text | ConvertFrom-Json
      Write-Output "Blob is JSON with this shape (values hidden):"
      Show-Shape $j '  '
    } catch {
      Write-Output ("Blob is not JSON (decoded length {0} chars)" -f $text.Length)
    }
  }
} finally {
  [CredEnum]::CredFree($ptr)
}
if ($found -eq 0) { Write-Output "No credential entry with a target matching gemini|antigravity|agy." }
