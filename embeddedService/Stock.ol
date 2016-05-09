include "../config/constants.iol"
include "file.iol"
include "../interfaces/stockInterface.iol"
include "../interfaces/marketInterface.iol"

include "console.iol"
include "string_utils.iol"
include "runtime.iol"
include "time.iol"
include "math.iol"


// le seguenti definizioni di interfaccia e outputPort consento un'invocazione "riflessiva"
interface LocalInterface {
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

define randGen {
// Returns a random number d such that 0.0 <= d < 1.0.
    random@Math()( rand );
// genera un valore random, estremi inclusi
    amount = int(rand * (upperBound - lowerBound + 1) + lowerBound)
}


execution { concurrent }

main {

// riceve in input la struttura dati di configurazione del nuovo stock (StockSubStruct)
    [ start( stockConfig )() {
        install ( IOException => println@Console( "caught IOException :  Market is down" )() );

/*
        valueToPrettyString@StringUtils( stockConfig )( result );
        println@Console( result )();
*/

        getProcessId@Runtime()( processId );
        println@Console( "start@Stock: ho appena avviato un client stock (" +
                            stockConfig.static.name + ", processId: " + processId + ")")();

        global.stockConfig << stockConfig;

// avvio la procedura di registrazione dello stock sul market
// compongo una piccola struttura dati con le uniche informazioni richieste dal market
        registrationStruct.name = stockConfig.static.name;
        registrationStruct.price = stockConfig.static.info.price;

        // Verifica lo stato del Market
        checkMarketStatus@StockToMarketCommunication()( server_conn );
        if (!server_conn) throw( IOException );

        registerStock@StockToMarketCommunication( registrationStruct )( response );

// who I am? Imposto la location della output port Self per comunicare con "me stesso"
        getLocalLocation@Runtime()( Self.location );

// posso adesso avviare l'operazione di wasting (deperimento), ovvero un thread parallelo e indipendente (definito
// come operazione all'interno del servizio Stock) dedicato allo svolgimento di tal operazione
        if ( stockConfig.static.info.wasting.interval > 0 ) {
            wasting@Self()
        };

// idem per production (leggi sopra)
        if ( stockConfig.static.info.production.interval > 0 ) {
            production@Self()
        }
    } ] { nullProcess }



    [ buyStock()( response ) {

        getProcessId@Runtime()( processId );

        me -> global.stockConfig;
        println@Console( "Sono " + me.static.name + " (processId: " + processId+ "); il market ha appena richiesto @buyStock" )();

        synchronized( syncToken ) {
            if ( me.dynamic.availability > 0 ) {
                me.dynamic.availability--;
                response = "Sono " + me.static.name + " (processId: " + processId+ "); decremento la disponibilità di stock"
            } else {

// TODO: lanciare un fault?
                response = "Sono " + me.static.name + " (processId: " + processId+ "); la disponibilità è terminata"
            }
        }

    } ] { nullProcess }



// riflettere: possono presentarsi casistiche per le quali sia necessario sollevare un fault?
    [ sellStock()( response ) {
        getProcessId@Runtime()( processId );

        me -> global.stockConfig;
        println@Console( "Sono " + me.static.name + " (processId: " + processId+ "); il market ha appena richiesto @sellStock" )();

        synchronized( syncToken ) {
            me.dynamic.availability++;
            response = "Sono " + me.static.name + " (processId: " + processId+ "); incremento la disponibilità di stock"
        }
    } ] { nullProcess }




// OneWay riflessivo; operazione di deperimento di unità dello stock
    [ wasting() ] {

        getProcessId@Runtime()( processId );

        me -> global.stockConfig;
        me.wasting -> me.static.info.wasting;
        println@Console( "Sono " + me.static.name + " (processId: " + processId+ "); ho appena avviato la procedura di WASTING" )();

        while ( true ) {

            synchronized( syncToken ) {

// la quantità residua è sufficiente per effettuare un deperimento
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
// effettuo l'arrotondamento a 2 decimali
                    roundRequest.decimals = 2;
                    round@Math( roundRequest )( wastingRate );

// decremento la quantità deperita alla quantità totale disponibile
                    oldAvailability = me.dynamic.availability;
                    me.dynamic.availability -= amount;

// TODO: sicuri sia sufficiente una OneWay?
                    stockWasting.name = me.static.name;
                    stockWasting.variation = wastingRate;

                    // Verifica lo stato del Market
                    checkMarketStatus@StockToMarketCommunication()( server_conn );
                    if (!server_conn) throw( IOException );

                    destroyStock@StockToMarketCommunication( stockWasting );

                    println@Console( "Sono " + me.static.name + " (processId: " + processId + "); WASTING di " + amount +
                                        " (da " + oldAvailability + " a " + me.dynamic.availability + "); wastingRate di " +
                                        roundRequest + " arrotondato a " + wastingRate + "; interval: " +
                                        me.production.interval + " secondi" )()
                }
            };

            sleep@Time( me.wasting.interval * 1000 )()
        }
    }



// OneWay riflessivo; operazione di produzione di nuove unità di stock
    [ production() ] {
        getProcessId@Runtime()( processId );

        me -> global.stockConfig;
        me.production -> me.static.info.production;
        println@Console( "Sono " + me.static.name + " (processId: " + processId+ "); ho appena avviato l'operazione di PRODUCTION" )();

        while ( true ) {
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
// effettuo l'arrotondamento a 2 decimali
                roundRequest.decimals = 2;
                round@Math( roundRequest )( productionRate );

// incremento la quantità totale disponibile della quantità prodotta
                oldAvailability = me.dynamic.availability;
                me.dynamic.availability += amount;

// TODO: sicuri sia sufficiente una OneWay?
                stockProduction.name = me.static.name;
                stockProduction.variation = productionRate;

                // Verifica lo stato del Market
                checkMarketStatus@StockToMarketCommunication()( server_conn );
                if (!server_conn) throw( IOException );

                addStock@StockToMarketCommunication( stockProduction );

                println@Console( "Sono " + me.static.name + " (processId: " + processId + "); PRODUCTION di " + amount +
                                    " (da " + oldAvailability + " a " + me.dynamic.availability + "); productionRate di " +
                                    roundRequest + " arrotondato a " + productionRate + "; interval: " +
                                    me.production.interval + " secondi" )()
            };

            sleep@Time( me.production.interval * 1000 )()
        }
    }

    /*
    * Operazione infoStockAvaliability dell'interfaccia StockInstanceInterface
    * local | Client: StocksMng | Server: Stock
    */
    [ infoStockAvaliability()( responseAvaliability ) {
        responseAvaliability = global.stockConfig.dynamic.availability
    } ] { nullProcess }

}
