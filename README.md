# HomeList

**HomeList je jednoduchá webová aplikace pro evidenci domácích zásob a sdílený rodinný nákupní seznam.**

> [!IMPORTANT]
> **Projekt je zatím určen výhradně pro soukromé účely a používání v rámci vlastní domácnosti / rodiny.**
>
> Nejde o veřejnou službu ani hotový komerční produkt. Aplikace není připravena pro veřejné nasazení, hromadné používání nebo provoz pro cizí domácnosti. Funkce, zabezpečení i provozní postupy se stále vyvíjejí.

## Co HomeList umí

- Evidovat potraviny a další domácí položky.
- Rozdělit zásoby podle umístění, například **Lednice**, **Mrazák** a **Spíž**.
- Vytvářet vlastní umístění a měnit jejich pořadí.
- Označit položku jako docházející a přidat ji na nákupní seznam.
- Rozdělovat nákupní seznam do kategorií.
- Přidávat štítky a filtrovat podle nich.
- Sdílet zásoby a nákupní seznam mezi členy jedné domácnosti.
- Připojit člena domácnosti pomocí jednorázového pozvánkového kódu.
- Vytvářet QR štítky pro jednotlivá umístění.
- Nainstalovat aplikaci jako PWA na podporovaném zařízení.
- Upozornit na dostupnou aktualizaci aplikace.

## Použité technologie

- HTML, CSS a JavaScript
- [Supabase](https://supabase.com/) – přihlášení, databáze a synchronizace
- [GitHub Pages](https://pages.github.com/) – hosting webové aplikace
- Progressive Web App (PWA) – instalace na zařízení a základní offline shell

## Jak aplikace funguje

Aplikace běží jako statický web na GitHub Pages. Uživatelská data se ukládají do databáze Supabase. Přihlášení probíhá přes Google účet.

Členové domácnosti sdílejí data prostřednictvím společné domácnosti. Přístup k jejím datům je řízen členstvím a pravidly Row Level Security (RLS) v Supabase. Pozvánkový kód slouží k připojení dalšího člena.

**Pozor:** veřejně dostupná webová stránka ani veřejný zdrojový kód neznamenají, že je aplikace určena veřejnosti. Přihlášení a databázová oprávnění jsou oddělené od dostupnosti samotné stránky.

## Spuštění

Aktuální nasazenou verzi najdeš zde:

Pro vlastní nasazení je potřeba připravit projekt Supabase, nastavit databázové tabulky, funkce a RLS politiky a nakonfigurovat veřejnou URL projektu a publishable klíč v aplikaci.

Do veřejného repozitáře nikdy nevkládej:
- Supabase `service_role` klíč,
- heslo k databázi,
- OAuth client secret,
- jiné soukromé přístupové údaje.

Veřejný publishable klíč používaný v klientské aplikaci není náhradou za správně nastavená RLS pravidla.

## Stav projektu a omezení

HomeList je osobní projekt ve vývoji. Některé části se mohou měnit a mohou se objevit chyby.

- Aplikace potřebuje připojení k internetu pro přihlášení, načítání a synchronizaci dat.
- PWA nabízí pouze základní offline shell; plnohodnotné offline používání zatím není podporováno.
- Dostupnost a chování instalace PWA se mohou lišit podle prohlížeče a zařízení.
- Projekt zatím nemá záruku dostupnosti, podpory ani garantovanou ochranu proti ztrátě dat. Důležitá data si pravidelně zálohuj.

## Soukromé použití

Tento projekt vzniká pro vlastní potřebu a používání v rámci rodiny. Pokud si prohlížíš jeho zdrojový kód, ber prosím na vědomí, že jde o průběžně vyvíjený osobní projekt, nikoli o nabídku veřejné služby.

---

<sub>HomeList · Soukromý projekt · Ve vývoji</sub>
