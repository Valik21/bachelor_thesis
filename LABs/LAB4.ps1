<#
Vytvoření proměnných pro importní/exportní soubory,
které budou dynamické podle aktuálního data.
#>
$date = (Get-Date)
$today = $date.ToString("yyyy-MM-dd")
$import = "C:\import\sync-users\sync-users_" + $today + ".csv"
$export = "C:\export\sync-users\sync-users_" + $today + ".txt"

<#
Vytvoření proměnných pro odeslání emailu, které proběhne na konci scriptu.
Proměnné $login a $password jsou z důvodu bezpečnosti uloženy v textovém souboru.
#>
$From = "sync-users@fim.cz"
$To = "it.department@fim.cz”
$Attachment = $export
$Subject = "Sync users in AD"
$Body = "<h2>Monthly report</h2><br><br>"
$SMTPServer = "smtp-relay.sendinblue.com"
$SMTPPort = "587"
$login = Get-Content C:\Import\smtp-login.txt
$password = Get-Content C:\Import\smtp-password.txt | ConvertTo-SecureString -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($login, $password)

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

#Import uživatelů z CSV souboru, uživatelé jsou odděleni pomocí ";".
$users = Import-Csv $import -Delimiter ";"

<#
Cyklus foreach, který pro každého zaměstnance ($user) v poli $users provede celý script,
až do řádku číslo 117.
Do proměnné $ADUsers se uloží všichni uživatelé domény, ostatní proměné se získají z importního CSV.
#>
foreach ($user in $users) {
    $firstName = $user.firstname
    $lastName = $user.lastname
    $userName = $user.username
    $upn = "$userName@$domain"
    $department = $user.department
    $expirationDate = $user.enddate
    $existingUser = Get-ADUser -Filter {SamAccountName -eq $userName}

    <#
    Podmínka, která přiřadí do proměnných ($OU a $GRP) správnou
    organizační jednotku a skupinu podle oddělení. 
    #>
    switch ($department) {
        "Admins"     {$OU = $OUAdmins
                      $GRP = $GAdmins}
        "Management" {$OU = $OUManagement
                      $GRP = $GManagement}
        "Marketing"  {$OU = $OUMarketing
                      $GRP = $GMarketing}
        "Sales"      {$OU = $OUSales
                      $GRP = $GSales}
    }

    <#
    Pokud existuje importovaný uživatel v doméně provede se následující
    blok podmínky, jinak se zapíše chyba do exportního souboru.
    #>
    if ($existingUser) {

        <#
        Vytvoření proměnných pro SamAccountName, současného příjmení a oddělení
        #>
        $SAN = $existingUser.SamAccountName
        $currentDepartment = (Get-ADUser -Identity $SAN -Properties Department).Department
        $currentSurname = $existingUser.Surname

        #Pokud je rozdílné oddělení z CSV souboru oproti současnému, provede se blok podmínky.
        if($currentDepartment -ne $department) {

            #Proměnné pro současnou skupinu.
            $currentGroup = "GRP_" + $currentDepartment

            try {

                <#
                Přesunutí uživatele do organizační jednotky podle oddělení,
                odebrání uživatele ze stávající skupiny a přidání do nové,
                změna oddělení.
                #>
                Move-ADObject -Identity $existingUser -TargetPath $OU
                Remove-ADGroupMember -Identity $currentGroup -Members $existingUser -Confirm:$False
                Add-ADGroupMember $GRP $existingUser 
                Set-AdUser $SAN -Department $department
                #Zapsání změny oddělení uživatele do exportního souboru.
                Write-Output "Username: $SAN, OU: $OU, Group: $GRP, Department: $department." | Add-Content $export
                
            } catch {

                #Zapsání chyby změny oddělení uživatele do exportního souboru.
                Write-Output "Username: $SAN -> error in department." | Add-Content $export
            }
        }

        #Pokud je rozdílné příjmení z CSV souboru oproti současnému, provede se blok podmínky.
        if($currentSurname -ne $lastName) {

            #Nové iniciály a display name.
            $initials = "$($firstName[0])$($lastName[0])"
            $displayName = "$firstname $lastname"

            try {

                #Změna příjmení uživatele v AD.
                Set-ADUser $SAN -Surname $lastName -Initials $initials -DisplayName $displayName 
                Rename-ADObject -Identity $existingUser -NewName $displayName
                #Zapsání změny příjmení uživatele do exportního souboru.
                Write-Output "Username: $SAN, Display Name: $displayName, Initials: $initials" | Add-Content $export
            
            } catch {

                #Zapsání chyby při změně příjmení uživatele do exportního souboru.
                Write-Output "Username: $SAN -> error in surname." | Add-Content $export
            }
        }

        #Pokud je u uživatele v CSV souboru vyplněn datum odchodu, provede se blok podmínky.
        if(-not [string]::isNullOrEmpty($expirationDate)) {
            
            #Nastaví se u uživatele v AD ExpirationDate
            Set-ADUser $SAN -AccountExpirationDate $expirationDate
            #Zapsání ExpirationDate pro uživatele do exportního souboru.
            Write-Output "Username: $SAN, ExpirationDate: $expirationDate." | Add-Content $export
        }

    } else {

        #Zapsání uživatel nenalezen do exportního souboru.
        Write-Output "Username: $userName not found" | Add-Content $export
    }
}
 
#Odeslání emailu pomocí proměnných vytvořených na začátku scriptu.
Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Usessl -Port $SMTPPort -Credential $credentials -Attachments $export -Priority Normal