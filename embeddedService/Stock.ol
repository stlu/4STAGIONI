include "../config/constants.iol"
include "file.iol"
include "../interfaces/commonInterface.iol"
include "../interfaces/stockInterface.iol"

include "console.iol"
include "string_utils.iol"
include "runtime.iol"
include "time.iol"
include "math.iol"



// le seguenti definizioni di interfaccia e outputPort consento un'invocazione "riflessiva"
interface LocalInterface {
    OneWay: registration( void ) // registrazione dello stock presso il market
    OneWay: wasting( void ) // deperimento
    OneWay: production( void ) // produzione
}
outputPort Self { Interfaces: LocalInterface }

// porta in ascolto per la comunicazione con l'embedder (StocksMng)
inputPort StockInstance {
    Location: "local"
    Interfaces: StockInstanceInterface, LocalInterface
}

// lo stock comunica in forma autonoma con il market per richieste in output
outputPort StockToMarketCommunication {
    Location: "socket://localhost:8001"
    Protocol: sodep
    Interfaces: StockToMarketCommunicationInterface, MarketCommunicationInterface
}



init {
// who I am? Imposto la location della output port Self per comunicare con "me stesso", ovvero con le operazioni esposte
// in LocalInterface
    getLocalLocation@Runtime()( Self.location );
    global.connAttempt = 0
}

define randGen {
// Returns a random number d such that 0.0 <= d < 1.0.
    random@Math()( rand );
// genera un valore random, estremi inclusi
    amount = int(rand * (upperBound - lowerBound + 1) + lowerBound)
}

// verifica lo stato del market (closed / down) e lancia le rispettive eccezioni
// (MarketClosedException || IOException)
define checkMarketStatus {
    checkMarketStatus@StockToMarketCommunication()( server_conn );
    if ( ! server_conn ) throw( MarketClosedException )
}

// gestisce una visualizzazione user friendly dell'output, nonchè un delay sui tentativi ciclici di connessione al market
define connAttemptTracking {
    println@Console( global.stockConfig.static.name + ": connection attempt to Market failed (" + ++global.connAttempt + "); try again in 5 seconds" )();

// dopo 5 tentativi lancio un halt che si propaga a StockMng e StocksLauncher
    if ( global.connAttempt == MAX_CONNECTION_ATTEMPTS ) {
        println@Console( CONNECTION_ATTEMPTS_MSG )();
        halt@Runtime()()
    };

    sleep@Time( 5000 )()
}



execution { concurrent }

main {

// registrazione dello stock sul market; intercetta eccezioni e gestisce i tentativi di connessione
    [ registration() ] {

// ho inserito il seguente scope per garantire la stampa di registrationScope.StockDuplicatedException.stockName
// TODO: soluzione più elegante?
        scope ( registrationScope ) {

            install(
// qualora il market sia down, si avvia una visualizzazione user friendly dei tentativi di connessione (cadenzati ogni 5 s)
// l'exception NON si propaga sino all'install definito nell'init                
                IOException => connAttemptTracking; registration@Self(),

// qualora lo stock tenti la registrazione ed il market sia chiuso, il recovery riesegue ciclicamente (via Self)
// l'operazione di registration con un delay di 5 secondi
                MarketClosedException => println@Console( MARKET_CLOSED_EXCEPTION )();
                                            sleep@Time( 5000 )(); registration@Self(),

// qualora lo stock sia già registrato, viene mostrato un errore a video;
// il flusso esecutivo porta al termine del thread
                StockDuplicatedException => println@Console( STOCK_DUPLICATED_EXCEPTION +
                                            " (" + registrationScope.StockDuplicatedException.stockName + ")")()
            );

            checkMarketStatus;

            me -> global.stockConfig;

// avvio la procedura di registrazione dello stock sul market
// compongo una piccola struttura dati con le uniche informazioni richieste dal market
            registrationStruct.name = me.static.name;
            registrationStruct.totalPrice = me.static.info.totalPrice;

// TODO: al momento riceve un bool true; è davvero necessario?
            registerStock@StockToMarketCommunication( registrationStruct )( response );

// posso adesso avviare l'operazione di wasting (deperimento), ovvero un thread parallelo e indipendente (definito
// come operazione all'interno del servizio Stock) dedicato allo svolgimento di tal operazione
            if ( me.static.info.wasting.interval > 0 ) {
                wasting@Self()
            };

// idem per production (leggi sopra)
            if ( me.static.info.production.interval > 0 ) {
                production@Self()
            }
        }
    }



// riceve in input la struttura dati di configurazione del nuovo stock (StockSubStruct)
// avvia l'operazione di registrazione sul market
    [ start( stockConfig )() {

/*
        valueToPrettyString@StringUtils( stockConfig )( result );
        println@Console( result )();
*/

        if ( DEBUG ) {
            getProcessId@Runtime()( processId );
            println@Console( "start@Stock: ho appena avviato un client stock (" +
                                stockConfig.static.name + ", processId: " + processId + ")")()
        };

        global.stockConfig << stockConfig;
        registration@Self()

    } ] { nullProcess }



// TODO: che tipo di risposta inviare al market? un boolean?
// oppure è sufficiente innescare un'eccezione    
    [ buyStock()( response ) {

        getProcessId@Runtime()( processId );

        me -> global.stockConfig;
        if ( DEBUG )
            println@Console( "Sono " + me.static.name + " (processId: " + processId+ "); il market ha appena richiesto @buyStock" )();

        synchronized( syncToken ) {
            if ( me.dynamic.availability > 0 ) {
                me.dynamic.availability--;
                if ( DEBUG )
                    println@Console("Sono " + me.static.name + " (processId: " + processId+ "); decremento la disponibilità di stock")();

// TODO: a mio avviso la seguente response è ridondante                
                response = true
            } else {

                if ( DEBUG )
                    println@Console("Sono " + me.static.name + " (processId: " + processId+ "); la disponibilità è terminata")();

// TODO: a mio avviso la seguente response è ridondante;
// il fault è correttamente intercettato da buyStock@Market
                response = false;

                throw( StockAvailabilityException, { .stockName = stockName } )
            }
        }

    } ] { nullProcess }



// riflettere: possono presentarsi casistiche per le quali sia necessario sollevare un fault?
// TODO: che tipo di risposta inviare al market? un boolean?
    [ sellStock()( response ) {
        getProcessId@Runtime()( processId );

        me -> global.stockConfig;
        if ( DEBUG )
            println@Console( "Sono " + me.static.name + " (processId: " + processId+ "); il market ha appena richiesto @sellStock" )();

        synchronized( syncToken ) {
            me.dynamic.availability++;
            if ( DEBUG )
                println@Console("Sono " + me.static.name + " (processId: " + processId+ "); incremento la disponibilità di stock")()
        };

// TODO: a mio avviso la seguente response è ridondante
        response = true
    } ] { nullProcess }



    [ infoStockAvailability()( response ) {
        me -> global.stockConfig;
// TODO: dev'essere synchronized poichè potrebbero verificarsi letture e scritture simultanee. Sicuri?
// Beh, direi di si. Il problema è riconducibile al paradigma dei lettori | scrittori.
// Posso favorire letture simultanee (prive di alcuna interferente scrittura); ma debbo prevenire
// letture e scritture simultanee (il lettore potrebbe leggere dati incongruenti, parzialmente scritti)
// ... da riguardare ...
        synchronized( syncToken ) {
            response = me.dynamic.availability
        }
    } ] { nullProcess }



// OneWay riflessivo; operazione di deperimento di unità dello stock
    [ wasting() ] {
        install(
// il market è down, errore irreversibile; ogni tentativo di recovery pulito equivarrebbe ad un lavoro mastodontico!
// interrompo l'esecuzione del programma
            IOException => println@Console( MARKET_DOWN_EXCEPTION )(); halt@Runtime()(),
// 04-jun-16            
// una "semplice" chiusura del mercato comporta invece una "semplice" attesa
// in altri termini: qualora il mercato sia chiuso, lo stock NON può deperire
// (implementare il contrario mi sembra complicato...)
// scelta progettuale da documentare opportunamente
            MarketClosedException => println@Console( MARKET_CLOSED_EXCEPTION )();
                                        sleep@Time( 5000 )();
                                        wasting@Self()
        );

        me -> global.stockConfig;
        me.wasting -> me.static.info.wasting;

        if ( DEBUG ) {
            getProcessId@Runtime()( processId );
            println@Console( "Sono " + me.static.name + " (processId: " + processId+ "); ho appena avviato la procedura di WASTING" )()
        };        

        while ( true ) {

// effettuo tal verifica prima di eseguire qualsiasi altra istruzione poichè le modifiche apportate alle strutture dati
// locali potrebbero non propagarsi al market
            checkMarketStatus;

            synchronized( syncToken ) {

// direttamente dalle specifiche:
// "quando uno Stock arriva a 0 in seguito ad un Deperimento, il prezzo del bene rimane invariato,
// e.g., il Grano ha 1 unità con costo 40, viene Deperito di 3, la disponibilità scende a 0 ma il prezzo rimane 40"
// e ancora: "gli Stocks non possono deperire al di sotto dello 0;"

// la disponibilità residua è già 0? procedo "d'ufficio" confermando la disponibilità
// oppure
// la dispnibilità è minore o uguale alla soglia minima di deperimento?
// la quantità da deperire è una scelta obbligata ed equivale esattamente alla quantità disponibile | residua
// non avvio alcuna comunicazione al merket; il prezzo rimane invariato
                if ( ( me.dynamic.availability == 0 ) || ( me.dynamic.availability <= me.wasting.low ) ) {
                    me.dynamic.availability = 0

                } else {

// procedo con il calcolo del deperimento random
                    lowerBound = me.wasting.low;
                    upperBound = me.wasting.high;
                    randGen; // la procedura calcola un valore random nell'intervallo indicato ed imposta la variabile amount

// se il valore generato (ovvero la quantità da deperire) è > della disponibilità effettiva,    
// procedo "d'ufficio" impostanto la disponibilità a 0
// la quantità deperità equivarrà alla disponibilità residua
// non avvio alcuna comunicazione al merket; il prezzo rimane invariato         
                    if ( amount > me.dynamic.availability ) {
                        me.dynamic.availability = 0

// caso "standard"
                    } else {

/*
Direttamente dalle specifiche:
"Ad esempio, se prima c’erano 20 unità di Grano e ne deperiscono 3, lo
Stock di Grano comunicherà al Market il dato 0.15 (corrispondente a 3/20). Dato che è diminuita
l’offerta del Grano, il Market aumenta il prezzo totale del Grano del 15%."

E' quindi necessario comunicare al market un valore decimale da cui verrà poi calcolato un incremento di prezzo
*/


// quantità deperita / quantità totale corrente
                        roundRequest = double( amount ) / double( me.dynamic.availability );
// effettuo l'arrotondamento al numero di decimali indicati in constants.iol
                        roundRequest.decimals = DECIMAL_ROUNDING;
                        round@Math( roundRequest )( wastingRate );

                        oldAvailability = me.dynamic.availability;

// compongo la struttura dati da passare al market
                        stockWasting.name = me.static.name;
                        stockWasting.variation = wastingRate;

// nb. è una semplice OneWay
                        destroyStock@StockToMarketCommunication( stockWasting );
// decremento la quantità deperita alla quantità totale disponibile;
                        me.dynamic.availability -= amount;

                        if ( DEBUG ) {
                            getProcessId@Runtime()( processId );
                            println@Console( "Sono " + me.static.name + " (processId: " + processId + "); WASTING di " + amount +
                                        " (da " + oldAvailability + " a " + me.dynamic.availability + "); wastingRate di " +
                                        roundRequest + " arrotondato a " + wastingRate + "; interval: " +
                                        me.wasting.interval + " secondi" )()
                        }
                    }
                }
            };

            sleep@Time( me.wasting.interval * 1000 )()
        }
    }



// OneWay riflessivo; operazione di produzione di nuove unità di stock
    [ production() ] {
        install(
// il market è down, errore irreversibile; ogni tentativo di recovery pulito equivarrebbe ad un lavoro mastodontico!
// interrompo l'esecuzione del programma            
            IOException => println@Console( MARKET_DOWN_EXCEPTION )(); halt@Runtime()(),
// 04-jun-16            
// una "semplice" chiusura del mercato comporta invece una "semplice" attesa
// in altri termini: qualora il mercato sia chiuso, lo stock NON può produrre nuove unità
// scelta progettuale da documentare opportunamente
            MarketClosedException => println@Console( MARKET_CLOSED_EXCEPTION )();
                                        sleep@Time( 5000 )();
                                        production@Self()
        );

        me -> global.stockConfig;
        me.production -> me.static.info.production;

        if ( DEBUG ) {
            getProcessId@Runtime()( processId );
            println@Console( "Sono " + me.static.name + " (processId: " + processId+ "); ho appena avviato l'operazione di PRODUCTION" )()
        };        

        while ( true ) {

// effettuo tal verifica prima di eseguire qualsiasi altra istruzione poichè le modifiche apportate alle strutture dati
// locali potrebbero non propagarsi al market
            checkMarketStatus;

            synchronized( syncToken ) {

                lowerBound = me.production.low;
                upperBound = me.production.high;
                randGen; // la procedura calcola un valore random nell'intervallo indicato ed imposta la variabile amount

// da specifiche: "quando uno Stock è a 0 e c’è una Produzione, il prezzo del bene rimane invariato, 
// e.g., il Grano ha 0 unità e prezzo registrato 40, ne vengono prodotte 3 unità dal relativo Stock, il Market
// aggiorna le unità di Grano disponibili ma il prezzo rimane 40.
                if ( me.dynamic.availability == 0 ) {
                    me.dynamic.availability = amount;

                    if ( DEBUG ) {
                        getProcessId@Runtime()( processId );
                        println@Console( "Sono " + me.static.name + " (processId: " + processId + "); PRODUCTION di " + amount +
                                            " (da 0 a " + me.dynamic.availability + ");" +
                                            " interval: " + me.production.interval + " secondi" )()
                    }

                } else {

/*
Direttamente dalle specifiche:

"Ad esempio, se prima della produzione c’erano 20 unità di Grano e ne vengono prodotte 2,
lo Stock di Grano comunicherà al Market il dato 0.1 (corrispondente a 2/20).
Dato che è aumentata l’offerta del Grano, il Market diminuisce il prezzo totale del Grano del 10%."

E' quindi necessario comunicare al market un valore decimale da cui verrà poi calcolato un decremento di prezzo
*/

// quantità prodotta / quantità totale corrente
                    roundRequest = double( amount ) / double( me.dynamic.availability );
// effettuo l'arrotondamento al numero di decimali indicati in constants.iol
                    roundRequest.decimals = DECIMAL_ROUNDING;
                    round@Math( roundRequest )( productionRate );

// incremento la quantità totale disponibile della quantità prodotta
                    oldAvailability = me.dynamic.availability;

// compongo la struttura dati da passare al market
                    stockProduction.name = me.static.name;
                    stockProduction.variation = productionRate;

                    addStock@StockToMarketCommunication( stockProduction );

                    me.dynamic.availability += amount;

                    if ( DEBUG ) {
                        getProcessId@Runtime()( processId );
                        println@Console( "Sono " + me.static.name + " (processId: " + processId + "); PRODUCTION di " + amount +
                                            " (da " + oldAvailability + " a " + me.dynamic.availability + "); productionRate di " +
                                            roundRequest + " arrotondato a " + productionRate + "; interval: " +
                                            me.production.interval + " secondi" )()
                    }
                }
            };

            sleep@Time( me.production.interval * 1000 )()
        }
    }
}