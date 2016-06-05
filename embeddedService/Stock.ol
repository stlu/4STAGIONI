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
    if ( global.connAttempt == 5 ) {
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

// rilancia a StocksMng il fault ricevuto dal market; no, per il momento gestisco tutto con questo install
// 04-jun-16: credo sia una buona soluzione definitiva
//            StockDuplicatedException => throw( StockDuplicatedException )
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
                response = true
            } else {

// TODO: lanciare un fault? Ad esempio un NoAvailabilityException
// potrebbe essere un'idea propagarla, passando per StocksMng e Market, sino ad un avviso al Player
                if ( DEBUG )
                    println@Console("Sono " + me.static.name + " (processId: " + processId+ "); la disponibilità è terminata")();
                response = false
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
                println@Console("Sono " + me.static.name + " (processId: " + processId+ "); incremento la disponibilità di stock")();
            response = true
        }
    } ] { nullProcess }



    [ infoStockAvailability()( response ) {
        me -> global.stockConfig;
// dev'essere synchronized poichè potrebbero verificarsi letture e scritture simultanee
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

// la quantità residua è sufficiente per effettuare un deperimento?
                if ( me.dynamic.availability >= me.wasting.high ) {
                    lowerBound = me.wasting.low;
                    upperBound = me.wasting.high;
                    randGen; // la procedura imposta la variabile amount

/*
Direttamente dalle specifiche:
"Ad esempio, se prima c’erano 20 unità di Grano e ne deperiscono 3, lo
Stock di Grano comunicherà al Market il dato 0.15 (corrispondente a 3/20). Dato che è diminuita
l’offerta del Grano, il Market aumenta il prezzo totale del Grano del 15%."

E' quindi necessario comunicare al market un valore decimale da cui verrà poi calcolato un incremento di prezzo
*/

// quantità deperita / quantità totale corrente
                    roundRequest = double( amount ) / double( me.dynamic.availability );
// effettuo l'arrotondamento a 5 decimali
                    roundRequest.decimals = 5;
                    round@Math( roundRequest )( wastingRate );

// decremento la quantità deperita alla quantità totale disponibile
                    oldAvailability = me.dynamic.availability;
                    me.dynamic.availability -= amount;

// compongo la struttura dati da passare al market
                    stockWasting.name = me.static.name;
                    stockWasting.variation = wastingRate;

// TODO: sicuri sia sufficiente una OneWay?
                    destroyStock@StockToMarketCommunication( stockWasting );

                    if ( DEBUG ) {
                        getProcessId@Runtime()( processId );
                        println@Console( "Sono " + me.static.name + " (processId: " + processId + "); WASTING di " + amount +
                        " (da " + oldAvailability + " a " + me.dynamic.availability + "); wastingRate di " +
                        roundRequest + " arrotondato a " + wastingRate + "; interval: " +
                        me.wasting.interval + " secondi" )()
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
                randGen; // la procedura imposta la variabile amount

/*
Direttamente dalle specifiche:

"Ad esempio, se prima della produzione c’erano 20 unità di Grano e ne vengono prodotte 2,
lo Stock di Grano comunicherà al Market il dato 0.1 (corrispondente a 2/20).
Dato che è aumentata l’offerta del Grano, il Market diminuisce il prezzo totale del Grano del 10%."

E' quindi necessario comunicare al market un valore decimale da cui verrà poi calcolato un decremento di prezzo
*/

// quantità prodotta / quantità totale corrente
                roundRequest = double( amount ) / double( me.dynamic.availability );

// effettuo l'arrotondamento a 5 decimali
                roundRequest.decimals = 5;
                round@Math( roundRequest )( productionRate );
// incremento la quantità totale disponibile della quantità prodotta
                oldAvailability = me.dynamic.availability;
                me.dynamic.availability += amount;

// compongo la struttura dati da passare al market
                stockProduction.name = me.static.name;
                stockProduction.variation = productionRate;
// TODO: sicuri sia sufficiente una OneWay?
                addStock@StockToMarketCommunication( stockProduction );

                if ( DEBUG ) {
                    getProcessId@Runtime()( processId );
                    println@Console( "Sono " + me.static.name + " (processId: " + processId + "); PRODUCTION di " + amount +
                                        " (da " + oldAvailability + " a " + me.dynamic.availability + "); productionRate di " +
                                        roundRequest + " arrotondato a " + productionRate + "; interval: " +
                                        me.production.interval + " secondi" )()
                }
            };

            sleep@Time( me.production.interval * 1000 )()
        }
    }
}