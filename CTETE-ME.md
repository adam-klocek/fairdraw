# Fairdraw: český návod / Czech quick start

Aplikace zobrazuje češtinu a angličtinu současně. Většina textu má velikost nejméně 18 px, tlačítka jsou větší a barvy výraznější.

Rozbalte ZIP, otevřete složku `fairdraw-shiny` v RStudiu a spusťte:

```r
source("install.R", encoding = "UTF-8")
shiny::runApp()
```

Závislosti se instalují pouze poprvé. Součástí je balíček `pdftools`; při instalaci ze zdrojů na Linuxu může vyžadovat systémový balíček `libpoppler-cpp-dev`.

1. Po otevření je již načten dodaný export PDF. Tlačítkem **Importovat seznam / Import list** můžete načíst jiný Excel nebo PDF.
2. U Excelu vyberte list a řádek záhlaví. U PDF použijte stejné rozložení jako v dodaném exportu faktur. Skenované dokumenty a jiná rozložení tento import nepodporuje.
3. Podle záměru vyberte ID: **Číslo dokladu** znamená jednu šanci na fakturu; **Číslo zákazníka** se zapnutým odstraněním duplicit jednu šanci na zákazníka. Zachovává se první výskyt před použitím podmínek. Aplikace nesčítá nákupy zákazníka.
4. Přidejte podmínky podle libovolného sloupce. Příklady: částka alespoň `1000,00`, platba `KARTA`, datum po `01.09.2026` nebo porovnání hodnot dvou sloupců.
5. Vyberte počet vítězů a náhradníků. Po stisknutí **Vylosovat vítěze / Pick a winner** se kolo točí 30 sekund. Odpočet ukazuje zbývající čas. Animaci lze přeskočit, aniž by se změnil výsledek.
6. V záznamu losování stáhněte auditní JSON, výsledky do Excelu nebo nový certifikát. Certifikát otevřete v prohlížeči a vytiskněte, případně uložte jako PDF.

Štít na certifikátu znamená, že Fairdraw zkontroloval kontrolní součet a zopakoval stejný výběr. Jde o ověření aplikací, nikoli o nezávislou certifikaci. Auditní JSON obsahuje celý seznam účastníků; certifikát a výsledkový Excel obsahují vylosované položky.

Historie je uložena jen po dobu relace Shiny. Před zavřením exportujte záznamy JSON. V sekci **Ověřit losování / Verify a draw** je lze načíst a přidat zpět do historie.

Podrobný anglický popis a technické limity jsou v `README.md`. Testy spustíte příkazem `Rscript tests/run_tests.R`. V prostředí, kde projekt vznikl, není R nainstalováno, takže testy R a skutečný běh aplikace nebyly provedeny. Testy časování animace a nezávislá kontrola dodaného PDF proběhly úspěšně.
