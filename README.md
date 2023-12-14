# KSMessaging (Suomi.fi-viestit ja paperikirjeet)

Tässä dokumentissa on kuvattu lyhyesti KSMessagingin käyttöönotto suomi.fi ja iPost-viestien osalta.

Suomi.fi viestien käyttöönottamiseksi tarvitaan lisäksi sopimukset Digi- ja väestötietoviraston (DVV) kanssa sekä tunnukset Valtion Integraatioalustalle (VIA). Tunnukset ja muut tarvittavat tiedot toimittaa DVV sopimuksen teon yhteydessä. Tutustu myös DVV:n Suomi.fi -viestien tekniseen aineistoon osoitteessa: https://esuomi.fi/palveluntarjoajille/viestit/tekninen-aineisto/. Käyttöönoton yhteydessä DVV toimittaa erikseen testausohjeet.

iPost-viesteille tarvitaan sopimus e-kirjepalveluntarjoajan kanssa, käytännössä PostiMessagingin tai RopoCapitalin. Paperikirjeitä voidaan lähettää joko iPostPDF tai iPostEPL-formaateissa. PostiMessagingin EPL Design Guide löytyy osoitteesta https://www.opuscapita.com/media/2019867/ipost-epl-design-guide-fi-en.pdf.

## Koha-palvelimella

### Konfiguroi halutut viestintärajapinnat koha-conf.xml:n "ksmessaging" osassa:

Suomi.fi viestintä: suomifi->branches->default osassa voidaan määritellä oletuskonfiguraatio, jota käytetään jos kirjastoyksikkökohtaisia määrittelyjä ei ole (eli käytännössä useimmiten). Kirjastoyksikkö/default-osan alle määritellään käytettävä rajapinta (ipostpdf tai wsapi), sekä iPostPDF-rajapintaa käytettäessä lisäksi FileTransfer-osa tiedostojen siirtämistä varten. Default-osa on suositeltava paikka määritellä asetukset, kirjastoyksikkökohtaisia määrityksiä tulisi käyttää ainoastaan poikkeustapauksissa. Esimerkiksi jos kimpan ulkopuolinen, mutta kimpan järjestelmässä oleva kirjasto haluaa lähettää suomi.fi -viestejä.

e-kirjeet (iPost): letters->branches->default osassa voidaan määritellä oletuskonfiguraatio, jota käytetään jos kirjastoyksikkökohtaisia määrittelyjä ei ole (eli käytännössä useimmiten). Kirjastoyksikkö/default-osan alle määritellään käytettävä rajapinta (ipostpdf tai ipostepl), sekä FileTransfer-osa tiedostojen siirtämistä varten. Default-osa on suositeltava paikka määritellä asetukset, kirjastoyksikkökohtaisia määrityksiä tulisi käyttää ainoastaan poikkeustapauksissa. Esimerkiksi jos kimpan ulkopuolinen, mutta kimpan järjestelmässä oleva kirjasto haluaa lähettää iPost-viestejä.

ipostpdf/ipostepl ja filetransfers -osat voidaan määritellä toisistaan riippumatta. Esimerkiksi on mahdollista käyttää tiedostojen siirtoon aina default-osan sisällä olevia määrityksiä ja muihin asetuksiin kirjastoyksikkökohtaisen osan sisällä olevia määrityksiä, tai päinvastoin.

**Kirjastoyksikkö/default-osassa määritellään:**

- Kirjeiden valmisteluhakemisto (stagingdir), paikallinen hakemisto johon kirjeaineistot muodostetaan ennen niiden siirtämistä valtion integraatiopalveluun tai e-kirjepalveluntarjoajan järjestelmään. Koha-Suomen järjestelmissä tähän käytetään /var/spool/koha/pate-staging -hakemistoa.
  - Huomaa että lähetettyjä tiedostoja ei automaattisesti siivota pois tästä hakemistosta niiden lähetyksen jälkeen, mutta hakemistossa olevia vanhoja tiedostoja ei kuitenkaan tästä huolimatta lähetetä uudelleen. Hakemiston siivous kannattaa ajastaa tapahtuvaksi erikseen.
- Yhteyshenkilö (contact), sähköpostiosoite, johon a) VIA/DVV ilmoittaa viestien käsittelyssä tapahtuneista virheistä, ja b) e-kirjepalveluntarjoaja toimittaa EPL-sanomien testiviestit silloin kun EPL-asetuksissa on testilippu käytössä. Koha-Suomi -kirjastojen osalta on suositeltavaa käyttää tässä Koha-Suomen notifications -sähköpostia.

**Kirjastoyksikkö/default-osan sisällä olevassa ipostpdf-osassa määritellään:**

- kuoritus- ja postituspalvelun käyttäjätunnus ja salasana (customerid, customerpass)
  - Nämä täytyy määritellä myös suomi.fi-viestejä varten, vaikka kirjepostitusta ei suomi.fi:n kautta käytettäisikään!
  - Tunnus on kuusinumeroinen asiakastunnus. Suomi.fi:ssä tunnukseksi voidaan asettaa esimerkiksi merkkijono 123456 ja salasana voi olla mitä tahansa silloin kun tulostus- ja kuorituspalvelu suomi.fi -viestien kanssa ei ole käytössä.
- 12-numeroinen OVT-laskutustunnus (ovtid), joka niinikään on pakollinen, vaikkei kirjeiden lähetystä ja siten myöskään niiden laskutusta tapahtuisikaan. Käytä tässä esimerkiksi kimpan keskuskirjaston OVT-tunnusta.
- Kuoritus- ja tulostuspalveluntarjoaja (printprovider), edelleen pakollinen, riippumatta siitä kuoritetaanko ja tulostetaanko. Tässä voi olla vaikkapa esimerkkikonfiguraatiotiedoston mukainen "Edita".
- Lähettäjän tunnus/viranomaistunnus (senderid), tämän saa suomi.fi viestejä varten DVV:lta.
- Tiedostotunniste (fileprefix), tiedostonimen alkuun liitettävä aineiston lähettäjän tunniste. Jos tämä on määrittelemättä, käytetään lähettäjän tunnusta. Lähettäjän tunnus ei kuitenkaan toimi tapauksissa, joissa tunnus sisältää _ -merkkejä, koska suomi.fi -viestipalvelu on varsin kranttu tiedostonnimien suhteen. Hyvä kandidaatti tähän on esimerkiksi yksinkertaisesti "koha". Eri e-kirjepalveluntarjoajilla voi olla omia vaatimuksiaan tiedostojen nimeämisen suhteen.

**Kirjastoyksikkö/default-osan sisällä olevassa ipostepl-osassa määritellään:**

- Viestien merkistökoodaus (encoding), joka voi olla joko ISO-8859-1 tai UTF-8. Oikea merkistökoodaus tulee sopia e-kirjepalveluntarjoajan kanssa. ISO-merkistöä käytettäessä rajapinta karsii suurimman osan aksenteista ja diakriiteistä pois kirjeen teksteistä, jolloin esimerkiksi nimeke "La belle Hélène" tulee kirjeelle muotoon "La belle Helene". Å:t ä:t ja ö:t säilyvät.
- EPL-kirjeiden otsikko (header), joka sisältää mm. e-kirjepalvelun käyttäjätunnuksen ja salasanan.
- Osastokoodi (code) jos sellaista halutaan käyttää. Header-osassa pitää tällöin olla merkkipaikassa 22 D.
- Asetteluosassa (layout) määritellään lomakepohjakoodit kirjeen etusivulle (templatecode) ja jatkosivuille (contpagecode) sekä kummallekkin templatelle mahtuvien tekstirivien määrä sivutusta varten (firstpage, otherpages). Katso myös ohje EPL-lomakepohjien määrityksiin.

**Kirjastoyksikkö/default-osan sisällä olevassa filetransfer-osassa määritellään:**

- Suomi.fi -vieteille valtion integraatioalustan palvelinosoite (host), testiympäristön osoite on qat.integraatiopalvelu.fi (192.49.232.194) ja tuotantoympäristön pr0.integraatiopalvelu.fi (192.49.232.195). Käytä joko nimeä tai IP-osoitetta.
- Palvelimen portti (port), määritys ei ole pakollinen. Käytettävän tiedonsiirtoprotokollan oletusportti valitaan automaattisesti mikäli muuta ei ole määritelty.
- Kohdehakemisto palvelimella (remotedir), oletus on käyttäjän kotihakemisto
  - Valtion integraatioalusta haluaa viestit hakemistoon to_viestit/ipost, joten oikea asetus suomi.fi-viesteille tähän on "to_viestit/ipost".
  - Eri e-kirjepalveluntarjoajilla voi olla omia vaatimuksiaan tiedostojen kohdehakemiston suhteen.
- Käyttäjätunnus ja salasana vastaanottavalla palvelimella (user, password).
  - Suomi.fi viesteille nämä saa DVV:lta, iPost-kirjeille kirjepalveluntarjoajalta.
- Käytettävä tiedonsiirtoprotokolla (protocol), joko sftp tai ftp. FTP-protokollan kanssa pitää erikseen huolehtia tiedonsiirtoväylän suojaamisesta, koska protokolla sinänsä on suojaamaton ja viesteissä liikkuu luottamuksellisia tietoja. Älä käytä FTP:tä.

### Määrittele yhteys sotu-siiloon koha-conf.xml:n "ssnProvider"-osassa Suomi.fi viestinnälle

Suomi.fi -viestintä nojaa henkilötunnuksiin, joten suomi.fi viestejä varten tarvitaan sotu-siiloyhteys. Henkilötunnusten hakemiseen siilosta voi käyttää joko suoraa tietokantayhteyttä (directDB) tai sotu-siilon web-liittymää (findSSN). Henkilötunnusten noutamiseen käytetään KohaSuomi::SSN::Access -modulia. Pelkkiä e-kirjeitä varten sotu-siiloyhteyttä ei tarvita.

**directDB:**

- Määritä koha-conf.xml:n ssnProvider-osan interface-kohtaan "directDB".
- Lisää siilon tietokantaan MariaDB-käyttäjä ja anna select-oikeus tietokannan ssn-tauluun.
- Varmista että lisäämäsi käyttäjä pääsee käsiksi tietokantaan Koha-kontista.
- Lisää koha-conf.xml:n ssnProvider-osan alle directDB-osa ja määrittele sen alle siilon tietokannan palvelinosoite (host), portti (port), sekä lisäämäsi MariaDB-käyttäjän käyttäjätunnus (user) ja salasana (password).
- Huomaa että directDB soveltuu käytettäväksi ainoastaan jos sekä Koha-palvelin että Sotu-siilo ovat samassa suojatussa verkossa, esimerkiksi kontainerisoituna samalla palvelimella tai fyysisesti samassa konesalissa sijaitsevilla palvelimilla! Se ei missään tapauksessa sovellu käytettäväksi esimerkiksi julkisen internetin yli.

**findSSN:**

- Määritä koha-conf.xml:n ssnProvider-osan url-kohtaan sotu-siilon www-osoite, mikäli se ei ole määritettynä.
- Määritä koha-conf.xml:n ssnProvider-osan interface-kohtaan "findSSN".
- Lisää sotu-siiloon user-tauluun käyttäjä, jolla on oikeus hakea sotuja siilosta.
- Lisää koha-conf.xml:n ssnProvider-osan alle findSSN-osa ja määrittele sen alle siiloon lisäämäsi käyttäjätunnus (user) ja salasana (password).

### Ajasta viestien lähetys.

pate.pl -skriptin kannattaa symlinkkata cronjobs-hakemistoon:

```
ln -s /home/koha/Koha/C4/KohaSuomi/Pate/pate.pl /home/koha/koha-suomi-utility/cronjobs/
```

Sen jälkeen crontabiin sopivat rivit viestien käsittelemistä varten, esimerkiksi:

```
*/5 07-22 * * *   $TRIGGER cronjobs/pate.pl --suomifi
50 20 * * *       $TRIGGER cronjobs/pate.pl --letters
```

Paperikirjeet (--letters) lähetetään tässä klo 20.50 joka päivä, koska ennen yhdeksää PostiMessagingin palveluun toimitetut kirjeet ehtivät käsittelyyn saman päivän ajoihin, jolloin ne päätyvät vastaanottajille nopeammin. Ainakin toivottavasti.

Lisäksi on hyvä ajastaa vanhojen kirjepakettien siivous valmisteluhakemistosta vaikkapa siten, että yli kaksi viikkoa vanhat kirjepaketit hävitetään:

```
00 23 * * *       find /var/spool/koha/pate-staging -name * -mtime +14 -exec rm -v {} \; >> /var/log/koha/cronjobs/clean_pate_staging.log 2>&1
```

## Kohan liittymässä

- Määrittele viestipohjat. Viestipohjien tulee olla puhdasta tekstiä. HTML-muotoiluja ei tueta, mutta rivinvaihdot säilytetään tekstiä ladottaessa.
- Kohan listailmaisimia (----) ei tarvita, ne tulevat turhaan näkyviin viestiin jos niitä käyttää. Katso ohje viestipohjien määrittelyyn: [[11_Työkalut#112-Ilmoitukset-ja-kuitit|Ilmoitukset ja kuitit]].
- Kielikohtaisissa viestipohjissa on uusi kohta 'suomifi', jonka alle suomi.fi viestipohjat määritetään.
- Jos haluat käyttää suomi.fi viestintää, käy kliksauttamassa Kohan järjestelmäasetuksissa "SuomiFiMessaging" asentoon "Enable".
- Kun SuomiFiMessaging on käytössä, on asiakkaan viestiasetuksissa uusi kohta 'suomifi'. Aseta asiakaskohtaisesti suomi.fi -viestitäpät asiakkaan haluamille viestityypeille. Katso ohje viestiasetusten tekoon: [[1_Asiakkaat#Asiakkaan-viestiasetukset|Asiakkaan viestiasetukset]]. Suomi.fi viestipalvelu tunnistaa asiakkaat henkilötunnuksen perusteella, joten varmista, että asiakkaan henkilötunnus on sotu-siilossa.

## Suomi.fi viestinnässä huomioitavia asioita

- Suomi.fi viestejä varten asiakkaalla tulee olla tili suomi.fi -viestipalvelussa. Tilin voi ottaa käyttöön osoitteessa: https://www.suomi.fi/viestit.
- Suomi.fi viestejä varten asiakkaan henkilötunnuksen on oltava sotusiilossa ja sen on oltava oikein. Jos asiakkaalla on väärä hetu, päätyvät viestit pahimmassa tapauksessa väärälle henkilölle. Yhteisöille tai hetuttomille viestiminen ei suomi.fi:n kautta onnistu, ja jos tämmöisille asiakkaille kliksii suomi.fi -viestitäppiä, niin tuloksena on "failed" tilaisia viestejä viestijonossa. Tilannetta voisi hieman parantaa tallentamalla Y-tunnukset sellaisille yhteisöasiakkaille, joilla sellainen on. Toistaiseksi Koha-Suomessa ei kuitenkaan ole yhtenäistä käytäntöä tai päätöstä Y-tunnusten tallentamisesta.
- Suomi.fi viestissä ei näy viestin sisältöä suoraan suomi.fi postilaatikossa. Viestissä näkyy ainoastaan otsikko "Kirjaston nimi, kirjastojen viestit". Viestin sisältönä on "Olet saanut dokumentin suomi.fi -viestipalveluun". Varsinainen viestin sisältö on viestin liitteenä olevassa PDF:ssä. Tämä on suomi.fi ipost-viestipalvelun rajoite, eikä sille ikävä kyllä oikein voi mitään Kohan päässä.
- Selaimissa PDF-lukuohjelma tulee mukana, mutta mobiililaitteissa pitää olla suomi.fi -sovelluksen lisäksi asennettuna myös PDF-lukuohjelma. Kaikki lukuohjelmat eivät suomi.fi -sovelluksen kanssa tunnu toimivan. Lisäksi avaamisongelmia voi aiheuttaa esimerkiksi mobiililaitteessa käytössä oleva sisällönsuodatus tai VPN-ohjelmisto. Ongelmista on raportoitu VIA:lle.
- PDF-dokumenttia on varsin hankala lukea kännykän pieneltä näytöltä. Viesti on taitettu suomi.fi palvelun vaatimusten mukaisesti SFS-2487 standardin kuvaamaa asettelumallia seuraten A4-paperille, jotta kirje voitaisiin toimittaa tarvittaessa eteenpäin paperikirjeenä.
- Kohasta voidaan lähettää suomi.fi-viesteinä Kohan normaalia viestikanavaa pitkin kulkevat viestit, eli noutoilmoitukset, laina- ja palautuskuitit ja eräpäivämuistutukset. Laskuja tai palautuskehotuksia ei voi lähettää, koska niiden lähetys toimii Kohassa eri tavalla. Ainakin palautuskehotusten lähetyksen yhdenmukaistaminen muiden Kohan viestityyppien kanssa olisi hyvä seuraava askel ja mahdollistaisi myös palautuskehotusten toimittamisen asiakkaan valitsemalla tavalla.

## EPL lomakepohjien määrittäminen e-kirjepalveluntarjoajan järjestelmässä

EPL-kirjeitä varten e-kirjepalveluntarjoajan järjestelmässä täytyy olla määriteltynä käytettävät lomakepohjat joita voidaan kutsua EPL-kirjeistä. Tiedot lomakepohjalle sijoitetaan seuraavasti:

- Lomakepohjan ylälaitaan voidaan sijoittaa kirjastokimpan logo ja mahdolliset yhteystiedot kirjeen lähettäjätiedon paikalle. Vaihtoehtoisesti siellä voidaan käyttäää pelkästään tekstimuotoista lähettäjätietoa, mutta lähettäjä on kuitenkin aina määriteltävä e-kirjepalveluntarjoajan järjestelmässä olevassa lomakepohjassa. KSMessaging ei lisää lähettäjätietoa EPL-muotoisiin kirjeisiin eikä sitä ole mahdollista lisätä Kohan kirjepohjaan.
- Kanavalla 1 tulee asiakirjan tyyppi ja päiväys, jotka e-kirjepalveluntarjoajan tulee sijoittaa kirjepohjalla niille kuuluvalle paikalle SFS-2487 asiakirjastandardin mukaisesti. Asiakirjan tyyppi määritellään Kohan kirjepohjan kentässä "Nimi".
- Kanavalla 2 tulee vastaanottajan nimi- ja osoitetiedot, jotka menevät kirjeeseen vastaanottajan tiedoille tarkoitetulle paikalle siten että tekstit asemoituvat oikein ikkunakuoren ikkunaan. KSMessaging lisää nämä tiedot kirjeeseen automaattisesti.
- Kanavalla 3 tulee kirjeen varsinainen leipäteksti, joka tulee sijoittaa vaakasuunnassa oikeaan sarkainpaikkaan SFS-2487 standardin mukaisesti.
- Kanavalla 3 tulee leipätekstin perässä allekirjoitustiedot. Tämä on se paikka, johon voidaan myös haluttaessa sijoittaa lähettävän kirjastoyksikön yhteystiedot Kohan kirjepohjiin, jolloin kirjeen "kimpan nimissä" lähettänyt kirjastoyksikkö tulee kirjeen allekirjoittajaksi.

EPL-kirjeitä voidaan testata ennen niiden lähettämistä asiakkaalle sijoittamalla EPL-headerin merkkipaikkaan 16 testilippu, T. Tällöin kirjeet eivät lähde asiakkaalle, vaan ne toimitetaan contact-tagin määrittelemään sähköpostiosoitteeseen. *Kirjeet liikkuvat testattaessa salaamattomina sähköposteina, joten älä koskaan käytä oikeita asiakkaita testaamiseen!* Testilippua käyttäen tekstien, logojen ym. asemointi kirjeelle on helppo tarkistaa ja tehdä tarvittavat säädöt KSMessaging rajapintaan, Kohan kirjepohjiin ja e-kirjepalveluntarjoajan lomakepohjaan ennen rajapinnan tuotantokäytön aloittamista.

## EPL-kirjeviestinnässä huomioitavia asioita

Aikaisemmasta EPL-rajapinnasta poiketen Kohan kirjepohjissa ei tule olla mitään EPL-ohjauskoodeja, muotoiluja, vastaanottajan tietoja tai muuta. Ainoastaan pelkkä kirjeen leipäteksti + allekirjoitus. Rajapinta + e-kirjepalveluntarjoajan lomake huolehtivat tekstien asettelusta paperille. Tämä on tärkeää, koska rajapinta latoo kaiken kirjepohjassa olevan tekstin suoraan kirjeelle, jolloin ylimääräiset ohjausmerkit ja muotoilut tulevat suoraan asiakkaalle lähtevään kirjeeseen! Tähän ratkaisuun on siirrytty siitä syystä, että tällä tavalla toimimalla sama kirjepohja toimii sekä iPostEPL, iPostPDF että suomi.fi -viestinnässä. Kirjepohjan muoto on riippumaton siitä millä tavalla viesti loppujen lopuksi toimitetaan asiakkaalle, jolloin kirjepohjien ylläpito Kohassa on paljon yksinkertaisempaa.

KSMessaging tekee tekstin sivutuksen automaattisesti perustuen rajapinnan konfiguraation layout-osassa määriteltyihin lomakekohtaisiin rivimääriin, mutta se ei tee tekstin rivitystä automaattisesti. Tekstin rivityksestä on siis huolehdittava Kohan kirjapohjassa.
