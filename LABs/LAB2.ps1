#Načtení .NET tříd.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing 

#Vytvoření formuláře.
$Form                    = New-Object system.Windows.Forms.Form
$Form.ClientSize         = '500,400'
$Form.text               = "Zdroj zamceni uzivatele"
$Form.BackColor          = "#ffffff"

#Vytvoření popisku.
$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = "Zadej login uzivatele"
$lbl.AutoSize = $true
$lbl.Width = 25
$lbl.Height = 10
$lbl.Location = New-Object System.Drawing.Point(20,15)

#Vytvoření popisku pro textbox.
$lblLogin = New-Object system.Windows.Forms.Label
$lblLogin.text = "Login:"
$lblLogin.AutoSize = $true
$lblLogin.width = 25
$lblLogin.height = 20
$lblLogin.location = New-Object System.Drawing.Point(20,40)

#Vytvoření textboxu.
$txtLogin = New-Object system.Windows.Forms.TextBox
$txtLogin.multiline = $false
$txtLogin.width = 300
$txtLogin.height = 20
$txtLogin.location = New-Object System.Drawing.Point(80,40)
$txtLogin.Focus()

#Vytvoření tlačítka Search.
$btnSearch = New-Object System.Windows.Forms.Button
$btnSearch.BackColor = "#00AFF0"
$btnSearch.Text = "Search"
$btnSearch.Width = 90
$btnSearch.Height = 30
$btnSearch.Location = New-Object System.Drawing.Point(390,40)
$btnSearch.add_Click($btnSearch_Click)

#Vytvoření tlačítka Unlock, které bude při spuštění formuláře skryto.
$btnUnlock = New-Object System.Windows.Forms.Button
$btnUnlock.BackColor = "#00AFF0"
$btnUnlock.Text = "Unlock"
$btnUnlock.Width = 90
$btnUnlock.Height = 30
$btnUnlock.Location = New-Object System.Drawing.Point(100,300)
$btnUnlock.Visible = $false
$btnUnlock.add_Click($btnUnlock_Click)

#Vytvoření listview, který bude rozdělen na 3 sloupce.
$list = New-Object System.Windows.Forms.ListView
$list.View = 'Details'
$list.Width = 460
$list.Height = 200
$list.Location = New-Object System.Drawing.Point(20,80)
$list.AutoResizeColumns(2)
$list.Columns.Count = 3
$list.Columns.Add("Uzivatel")
$list.Columns.Add("Zdroj")
$list.Columns.Add("Datum")

#Vytvoření tlačítka Cancel, při kliknutí na tlačítko se formulář zavře.
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.BackColor = "#ffffff"
$btnCancel.Text = "Cancel"
$btnCancel.Width = 90
$btnCancel.Height = 30
$btnCancel.Location = New-Object System.Drawing.Point(260,300)
$btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$Form.CancelButton = $btnCancel

#Přidání ovládání do formuláře.
$Form.Controls.AddRange(@($lbl,$lblLogin,$txtLogin,$btnSearch,$btnUnlock,$list,$btnCancel))

#Při kliknutí na tlačítko Search se provede následují akce.
$btnSearch_Click = {
    
    $existingUser = Get-ADUser -Filter {SamAccountName -eq $txtLogin.Text}
    
    <#
    Ověření, zda uživatel existuje, jinak vyskočí dialogové 
    okno s chybou.
    #>
    if ($existingUser) {

        try {
            #Vytvoření proměnných pro hledání událostí.
            $dc = (Get-ADDomain).PDCEmulator
            $eventID = 4740
            $date = (Get-Date).AddMinutes(-30)

            <#
            Do proměnné $event se uloží událost z event logu,
            ID 4740 odkazuje na uzamčení uživatele, čas události je
            maximálně 30 minut zpětně. 
            #>
            $event = Get-WinEvent -ComputerName $dc -FilterHashtable @{
                LogName = "Security"
                ProviderName = "Microsoft-Windows-Security-Auditing"
                StartTime = $date
                Id = $eventID
                data = $txtLogin.Text
            }

            <#
            Pokud se do proměnné $event uložila událost, vypíše se do listview.
            První sloupec představuje login uživatele, druhý zdroj zamčení a třetí
            čas zamčení, který ještě musí být převeden na String, jelikož listview 
            nepodporuje date formát. Nakonec dojde k zobrazení tlačítka Unlock.
            #>
            $item = New-Object System.Windows.Forms.ListViewItem($event.Properties[0].Value)
            $item.SubItems.Add($event.Properties[1].Value)
            $item.SubItems.Add($event.TimeCreated.ToString())
            $list.Items.Add($item)
            $btnUnlock.Visible = $true
        
        } catch {
            #Zobrazení dialogového okna s chybovou hláškou.
            [System.Windows.Forms.MessageBox]::Show("Akce se nezdarila", "Error")

        }

    } else {
        #Zobrazení dialogového okna s chybovou hláškou.
        [System.Windows.Forms.MessageBox]::Show("Uzivatel nenalezen", "Warning")

    }
}

#Při kliknutí na tlačítko Search se provede následují akce.
$btnUnlock_Click = {

    try {

        <#
        Odemčení uživatele a zobrazení dialogového okna.
        Smazání dat z texboxu a listview, nakonec se kurzor zobrazí
        v texboxu pro možnost psaní loginu dalšího uživatele.
        #>
        Unlock-ADAccount -Identity $txtLogin.Text
        [System.Windows.Forms.MessageBox]::Show("Uzivatel odemcen", "Success")
        $txtLogin.Clear()
        $list.Items.Clear($item)
        $list.Refresh()
        $txtLogin.Focus()

    } catch {
        #Zobrazení dialogového okna s chybovou hláškou.
        [System.Windows.Forms.MessageBox]::Show("Akce se nezdarila", "Error")
    }
}

#Spuštění formuláře.
[void]$Form.ShowDialog()