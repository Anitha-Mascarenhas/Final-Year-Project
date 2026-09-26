$rules = Get-NetFirewallRule -Direction Inbound -ErrorAction SilentlyContinue
foreach ($r in $rules) {
    $app = ($r | Get-NetFirewallApplicationFilter).Program
    if ($app -like '*python*') {
        Write-Output ($r.DisplayName + ' | ' + $r.Action + ' | ' + $r.Profile + ' | ' + $app)
    }
}
Write-Output '--- port 8000 listener ---'
Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
    $p = Get-Process -Id $_.OwningProcess
    Write-Output ('PID ' + $_.OwningProcess + ' path=' + $p.Path)
}
Write-Output '--- adapter network category ---'
Get-NetConnectionProfile | Format-Table Name,InterfaceAlias,NetworkCategory -AutoSize | Out-String -Width 120
