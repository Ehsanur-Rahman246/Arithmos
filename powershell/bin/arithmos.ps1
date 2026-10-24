#!/usr/bin/env pwsh
# Arithmos (PowerShell edition) entry point.
# No param block on purpose: every argument arrives in $args untouched.
$ErrorActionPreference = 'Stop'

# Dot-source at script level so every function lands in this scope.
. (Join-Path $PSScriptRoot '../src/autoload.ps1')

# Start-ArCli returns the exit status: 0 success, 1 Error [CODE], 2 bad usage.
$argv  = @($args | ForEach-Object { "$_" })
$codes = @(Start-ArCli $argv)
exit ([int]$codes[-1])