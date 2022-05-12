# Optimalizace správy Active Directory za využití Windows PowerShell

## LAB 1 - Uživatelská identita v AD
V prvním laboratorním cvičení je řešeno hromadné přidávání uživatelů do Active Directory. Script [LAB1.ps1](LABs/LAB1.ps1) 
nejdříve načte informace o uživatelích ze souboru, poté proběhne roztřídění uživatelů podle oddělení a tvorba loginu.
Na závěr je uživatel vytvořen a zařazen do organizační jednotky a skupiny podle oddělení. 

## LAB 2 - Zdroj zamčení uživatele
Ve druhém cvičení je řešen problém, kdy se uživateli opakovaně zablokuje účet v Active Directory. 
Pro Administrátora je zapotřebí, aby znal přesný zdroj zamčení. Proto je vytvořena GUI aplikace [LAB2.ps1](LABs/LAB2.ps1), do 
které stačí napsat login zamčeného uživatele. Aplikace poté vypíše zdroj a čas zamčení. Administrátor má poté
možnost uživatele i odblokovat.

## LAB 3 - Zablokování neaktivního uživatele / PC
Třetí cvičení klade důraz na bezpečnost. Je zapotřebí, aby byly neaktivní účty zablokovány a přesunuty do organizační 
jednotky Inactive. Script [LAB3.ps1](LABs/LAB3.ps1) prohledá všechny uživatele i počítače, kteří se do domény nepřihlásili více, 
jak týden. Jejich účty následně zablokuje a přesune do patřičné organizační jednotky. 

## LAB 4 - Změna pozice zaměstnance ve firmě
V posledním laboratorním cvičení je řešena reakce na změny ve firmě. Změny mohou nastat z různých
důvodů, například: změna pozice, změna příjemní, ukončení pracovního poměru. To vše je vhodné řešit automaticky,
pomocí scriptu [LAB4.ps1](LABs/LAB4.ps1).
