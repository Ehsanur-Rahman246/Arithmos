# Error model (ARCHITECTURE.md "Data flow"):
# engines throw an exception that carries a spec §2.2 code in Exception.Data['ArCode'].
# Only the CLI layer turns it into "Error [CODE]: message".

# ESC character, used by colour and cursor sequences.
$global:ArEsc = [string][char]27

function Throw-Ar {
    param([string]$Code, [string]$Message)
    $ex = [System.Exception]::new($Message)
    $ex.Data['ArCode'] = $Code
    throw $ex
}