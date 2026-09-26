# PoshanEye dev-machine firewall fix:
# 1) Disable the auto-created "python.exe" Block rules for Python 3.11 (they were
#    created when a firewall prompt was dismissed; they silently block the backend).
# 2) Add one scoped Allow rule: only the backend interpreter, only TCP 8000.
Get-NetFirewallRule -Direction Inbound | ForEach-Object {
    $app = ($_ | Get-NetFirewallApplicationFilter).Program
    if ($app -like '*python311*python.exe' -and $_.Action -eq 'Block') {
        Disable-NetFirewallRule -Name $_.Name
        Write-Output ("disabled block rule: " + $_.DisplayName + " [" + $_.Name + "]")
    }
}
New-NetFirewallRule -DisplayName 'PoshanEye backend (uvicorn 8000)' ` -Direction Inbound -Action Allow -Program 'C:\Users\Apeksha\AppData\Local\Programs\Python\Python311\python.exe' -Protocol TCP -LocalPort 8000 -Profile Any | Out-Null
Write-Output 'created allow rule: PoshanEye backend (uvicorn 8000)'
