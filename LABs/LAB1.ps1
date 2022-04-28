<#
Vytvoření proměnných pro doménu a importní/exportní soubory,
které budou dynamické podle aktuálního data.
#>
$domain = (Get-ADDomain).DNSRoot
$date = (Get-Date)
$today = $date.ToString("yyyy-MM-dd")
$import = "C:\import\new-users\new-users_" + $today + ".csv"
$export = "C:\export\new-users\new-users_" + $today + ".txt"

<#
Vytvoření proměnných pro odeslání emailu, které proběhne na konci scriptu.
Proměnné $login a $password jsou z důvodu bezpečnosti uloženy v textovém souboru.
#>
$From = "security@fim.cz"
$To = "itdepartment@fim.cz”
$Attachment = $export
$Subject = "New users in AD"
$Body = "<h2>Monthly report</h2><br><br>"
$SMTPServer = "smtp-relay.sendinblue.com"
$SMTPPort = "587"
$login = Get-Content C:\Import\smtp-login.txt
$password = Get-Content C:\Import\smtp-password.txt | ConvertTo-SecureString -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($login, $password)

#Import uživatelů z CSV souboru, uživatelé jsou odděleni pomocí ";".
$users = Import-Csv $import -Delimiter ";"

#Vytvoření proměnných pro organizační jednotky podle pracovní pozice.
$OUAdmins = "OU=Users,OU=Admins,OU=fim,DC=fim,DC=cz"
$OUManagement = "OU=Users,OU=Management,OU=fim,DC=fim,DC=cz"
$OUMarketing = "OU=Users,OU=Marketing,OU=fim,DC=fim,DC=cz"
$OUSales = "OU=Users,OU=Sales,OU=fim,DC=fim,DC=cz"

#Vytvoření proměnných pro skupiny podle pracovní pozice.
$GAdmins = "GRP_Admins"
$GManagement = "GRP_Management"
$GMarketing = "GRP_Marketing"
$GSales = "GRP_Sales"

<#
Cyklus foreach, který pro každého zaměstnance ($user) v poli $users provede celý script,
až do řádku číslo 129.
#>
foreach ($user in $users) {

    <#
    Do $ADUsers se uloží všichni existující uživatelé v doméně,
    tato proměnná bude dále využita pro ověření, zda již existuje v AD
    uživatel se stejným username, ostatní proměné se získají z importního CSV.
    #>
    $ADUsers = Get-ADUser -Filter * 
    $firstName = $user.firstname
    $lastName = $user.lastname
    $userName = "$($firstName[0])$lastName".ToLower()
    $initials = "$($firstName[0])$($lastName[0])"
    $upn = "$userName@$domain"
    $department = $user.department
    $displayName = "$firstname $lastname"

    <#
    Podmínka, která přiřadí do proměnných ($OU a $GRP) správnou
    organizační jednotku a skupinu podle oddělení. 
    #>
    switch ($department) {
        "Admins"        {$OU = $OUAdmins
                         $GRP = $GAdmins}
        "Management"    {$OU = $OUManagement
                         $GRP = $GManagement}
        "Marketing"     {$OU = $OUMarketing
                         $GRP = $GMarketing}
        "Sales"         {$OU = $OUSales
                         $GRP = $GSales}
    }

    #Vytvoření pomocných proměnných pro cyklus while.
    $defaultName = $userName
    $defaultLastName = $lastName
    $distinguishedName = "CN=" + $firstName + " " + $lastName + "," + $OU 
    $i = 1

    <#
    Dokud bude $userName shodný se SamAccountName v doméně,
    bude probíhat cyklus while.
    #>
    while ($ADUsers.SamAccountName -eq $userName) {

        <#
        Úprava $userName přidáním hodnoty $i, která se každým
        cyklem navyšuje.
        #> 
        $userName = $defaultName + [string]$i
        $upn = "$userName@$domain"

        <#
        Pokud je shodný i DistinguishedName, musí se upravit 
        i příjmení připsáním hodnoty $i.
        #>
        if ($ADUsers.DistinguishedName -eq $distinguishedName) {

            $lastName = $defaultLastName + [string]$i
        }
            $i++
    }

    #Vytvoření nového uživatele.
    New-ADUSer `
    -SamAccountName $userName `
    -UserPrincipalName $upn `
    -Name "$firstName $lastName" `
    -GivenName $firstName `
    -Surname $lastName `
    -Initials $initials `
    -Enabled $True `
    -DisplayName $displayName `
    -Path $OU `
    -EmailAddress $upn `
    -Department $department `
    -AccountPassword (Get-Content C:\Import\default-password.txt | `
    ConvertTo-secureString -AsPlainText -Force) `
    -ChangePasswordAtLogon $True

    #Přidání uživatele do skupiny podle pracovní pozice.
    Add-ADGroupMember $GRP $userName

    #Zapsání vytvořeného uživatele do exportního souboru.
    Write-Output "Username: $userName, OU: $OU, Group: $GRP" | Add-Content $export
    
}

#Odeslání emailu pomocí proměnných vytvořených na začátku scriptu.
Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Usessl -Port $SMTPPort -Credential $credentials -Attachments $export -Priority Normal



