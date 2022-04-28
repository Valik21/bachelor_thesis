<#
Vytvoření proměnné pro exportní soubor,
který bude dynamický podle aktuálního data.
Proměnná $lastWeek bude použita při filtrování 
neauktivních uživatelů a počítačů.
#>
$date = (Get-Date)
$lastWeek = $date.AddDays(-7)
$today = (Get-Date).ToString("yyyy-MM-dd")
$export = "C:\export\inactive-accounts\inactive-accounts_" + $today + ".txt"

<#
Vytvoření proměnných pro odeslání emailu, které proběhne na konci scriptu.
Proměnné $login a $password jsou z důvodu bezpečnosti uloženy v textovém souboru.
#>
$From = "security@fim.cz"
$To = "tomas1valenta@gmail.com”
$Attachment = $export
$Subject = "Inactive users and computers"
$Body = "<h2>Weekly report</h2><br><br>"
$SMTPServer = "smtp-relay.sendinblue.com"
$SMTPPort = "587"
$login = Get-Content C:\Import\smtp-login.txt
$password = Get-Content C:\Import\smtp-password.txt | ConvertTo-SecureString -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($login, $password)

<#
Vytvoření proměnných pro organizační jednotky, do kterých se budou
přesouvat něaktivní uživatelé a počítače.
#>
$OUInactiveUsers = "OU=Users,OU=Inactive,OU=fim,DC=fim,DC=cz"
$OUInactiveComputers = "OU=Computers,OU=Inactive,OU=fim,DC=fim,DC=cz"

<#
Nalezení neaktivních uživatelů a počítačů, ve filtru je ještě Enabled -eq $true,
aby se do proměnných neukládali již zablokované účty.
#>
$inactiveUsers = Get-ADUser -Filter {LastLogon -le $lastWeek -and Enabled -eq $true } 
$inactiveComputers = Get-ADComputer -Filter {LastLogon -le $lastWeek -and Enabled -eq $true }

#Pro každého uživatele v poli neaktivních uživatelů proběhne následující cyklus.
foreach ($user in $inactiveUsers) {

    <#
    Zablokování účtu a následné přesunutí do organizační
    jednotky Inactive -> users.
    #> 
    Disable-ADAccount -Identity $user
    Move-ADObject -Identity $user -TargetPath $OUInactiveUsers
    $user = $user.SamAccountName

    #Zapsání zablokovanáho uživatele do exportního souboru.
    Write-Output "Disabled user: $user, OU: $OUInactiveUsers." | Add-Content $export

}

#Pro každého uživatele v poli neaktivních uživatelů proběhne následující cyklus.
foreach ($computer in $inactiveComputers) {
    
    <#
    Zablokování účtu a následné přesunutí do organizační
    jednotky Inactive -> computers.
    #> 
    Disable-ADAccount -Identity $computer
    Move-ADObject -Identity $computer -TargetPath $OUInactiveComputers
    $computer = $computer.Name

    #Zapsání zablokovaného počítače do exportního souboru.
    Write-Output "Disabled computer: $computer, OU: $OUInactiveComputers." | Add-Content $export

}

#Odeslání emailu pomocí proměnných vytvořených na začátku scriptu.
Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Usessl -Port $SMTPPort -Credential $credentials -Attachments $export -Priority High