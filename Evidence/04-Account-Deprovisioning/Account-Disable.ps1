# Disable the target user
Disable-ADAccount -Identity amercer

# Confirm the state and userAccountControl bitmask
Get-ADUser -Identity amercer -Properties Enabled, userAccountControl | 
    Select-Object Name, SamAccountName, Enabled, userAccountControl | 
    Format-List