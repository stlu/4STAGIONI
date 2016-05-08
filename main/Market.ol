include "../config/constants.iol"
include "file.iol"
include "../interfaces/stockInterface.iol"
include "../interfaces/playerInterface.iol"
include "../interfaces/marketInterface.iol"

include "console.iol"
include "time.iol"
include "string_utils.iol"
include "math.iol"



outputPort MarketToStockCommunication { // utilizzata dal market per inviare richieste agli stock
    Location: "socket://localhost:8000"
    Protocol: sodep
    Interfaces: MarketToStockCommunicationInterface
}

inputPort StockToMarketCommunication { // utilizzata dagli stock per inviare richieste al market
    Location: "socket://localhost:8001"
    Protocol: sodep
    Interfaces: StockToMarketCommunicationInterface, MarketCommunicationInterface
}

inputPort PlayerToMarketCommunication { // utilizzata dai player per inviare richieste al market
    Location: "socket://localhost:8002"
    Protocol: sodep
    Interfaces: PlayerToMarketCommunicationInterface, MarketCommunicationInterface
}



execution { concurrent }

init {
    global.status = true // se true il Market è aperto
}

main {

/*
direttamente dalle specifiche del progetto
"registrarsi presso il Market. Gli Stocks si registrano presso il Market col proprio nome (e.g., "Oro", "Grano", "Petrolio")
e il proprio valore totale iniziale."

ricorda la composizione della struttura registeredStocks (su cui è applicabile il dynamic lookup)
registeredStocks.( stockName )[ 0 ].price

ricorda la composizione della struttura dati con la quale lo stock effettua l'operazione di registrazione
newStock.name
newStock.price
*/

// operazione esposta agli stocks sulla porta 8001, definita nell'interfaccia StockToMarketCommunicationInterface
    [ registerStock( newStock )( response ) {

// dynamic lookup rispetto alla stringa newStock.name
        if ( ! is_defined( global.registeredStocks.( newStock.name )[ 0 ] )) {
            global.registeredStocks.( newStock.name )[ 0 ].price = newStock.price;
            global.registeredStocks.( newStock.name )[ 0 ].name = newStock.name;
            valueToPrettyString@StringUtils( newStock )( result );
            println@Console( "\nMarket@registerStock, newStock:" + result )();
            response = "done"
        } else {
            /*  esiste uno stock con lo stesso nome è già registrato al market
             * (caso praticamente impossibile visto che StocksDiscoverer presta
             * particolare attenzione al parsing dei nomi dei nuovi stock)
             */
            throw( StockDuplicateException )
        }
    } ] { nullProcess }

/*
* Operazione registerPlayer dell'interfaccia playerInterface
* porta 8002 | Client: Player | Server: Market
*
* Da notare che differentemente da java dove strutture dati visibili in ogni
* parte del file (globali) sono definite all'inizio e ben in evidenza, in
* jolie la variabile globale Accounts (sarebbe 'di istanza' in java) non è
* dichiarata da nessuna parte, viene semplicemente creata quando arriva il
* primo player.
*/
    //Richiesta in entrata dal Player
    [ registerPlayer (incomingPlayer)(newAccount) {
        //Caso in cui il Player è nuovo
        if ( ! is_defined( global.accounts.(incomingPlayer) )) {
            with(global.accounts.(incomingPlayer)) {
                .name = incomingPlayer;
                with(.ownedStock) {
                    .name = "";
                    .quantity = -1
                };
                .liquidity = 100
            };
            newAccount << global.accounts.(incomingPlayer)
        } else {
            //Caso in cui il player fosse già presente, non dovrebbe verificarsi
            throw( PlayerDuplicateException )
        }
    } ] {
    println@Console( "\nregisterPlayer@Market, incomingPlayer: "
        + incomingPlayer )()
    }

// operazione esposta ai players sulla porta 8003, definita nell'interfaccia PlayerToMarketCommunicationInterface
// è tutto assolutamente da implementare!
    [ buyStock( stockName )( response ) {
        if ( is_defined( global.registeredStocks.( stockName )[ 0 ] )) {
            buyStock@MarketToStockCommunication( stockName )( response );
            println@Console( response )()
        } else {
            //Caso in cui lo stock non esiste
            throw( StockUnknownException )
        }
    } ] { nullProcess }

    [ sellStock( stockName )( response ) {
        if ( is_defined( global.registeredStocks.( stockName )[ 0 ] )) {
            sellStock@MarketToStockCommunication( stockName )( response );
            println@Console( response )()
        } else {
            //Caso in cui lo stock non esiste
            throw( StockUnknownException )
        }
    } ] { nullProcess }

    [ infoStockList( info )( responseInfo ) {
        i=0;
        foreach ( stockName : global.registeredStocks ) {
            responseInfo.name[i]=string( global.registeredStocks.(stockName)[ 0 ].name);
            i=i+1
        }
    } ] { nullProcess }

    [ infoStockPrice( stockName )( responsePrice ) {
      if ( is_defined( global.registeredStocks.( stockName )[ 0 ] )) {
          responsePrice=global.registeredStocks.( stockName )[ 0 ].price
      }
    } ] { nullProcess }

    [ infoStockAvaliability( stockName )( responseAvaliability ) {
      if ( is_defined( global.registeredStocks.( stockName )[ 0 ] )) {
      infoStockAvaliability@MarketToStockCommunication( stockName )( responseAvaliability )
      }
    } ] { nullProcess }

    /* Verifica lo stato del market */
    [ checkMarketStatus( )( responsestatus ) {
        if (global.status)  {
         responsestatus=true;
         responsestatus.message = "Market Open"
       } else {
         responsestatus=false;
         responsestatus.message = "Market Closed"
       }
     } ] { nullProcess }


// riceve i quantitativi deperiti da parte di ciascun stock; le richieste sono strutturate secondo StockVariationStruct
// (.name, .variation) definita all'interno di stockInterface.iol
    [ destroyStock( stockVariation )] {

/*
        valueToPrettyString@StringUtils( stockVariation )( result );
        println@Console( result )();
*/

        if ( is_defined( global.registeredStocks.( stockVariation.name ) )) {
            me -> global.registeredStocks.( stockVariation.name )[ 0 ]; // shortcut

            synchronized( syncToken ) {

                oldPrice = me.price;

// aggiorno il prezzo attuale (ricorda che entrambi sono tipi di dato double)
// il decremento del prezzo potrebbe generare una cifra con un numero di decimali > 2;
// sottraggo il decremento al prezzo attuale e successivamente effettuo una arrotondamento a 2 cifre decimali
                priceDecrement = me.price * stockVariation.variation;
                me.price -= priceDecrement;
// effettuo l'arrotondamento a 2 decimali
                roundRequest = me.price;
                roundRequest.decimals = 2;
                round@Math( roundRequest )( me.price );

// TODO
// che succede se il prezzo diventa < 0? (caso poco probabile ma possibile!)
// forse sarebbe opportuno utilizzare una RequestResponse e, qualora il decremento del prezzo non sia possibile,
// non procede con il deperimento della quantità di stock

                println@Console( "destroyStock@Market, " + stockVariation.name + "; prezzo attuale: " + me.price +
                                    "; variation " + stockVariation.variation + "; decremento del prezzo di " + priceDecrement +
                                    " (" + me.price + " * " + stockVariation.variation + "), " +
                                    "da " + oldPrice + " a " + me.price + ")")()
            }
        }
    }

// riceve i quantitativi prodotti da parte di ciascun stock; le richieste sono strutturate secondo StockVariationStruct
// (.name, .variation) definita all'interno di stockInterace.iol
    [ addStock( stockVariation )] {

/*
        valueToPrettyString@StringUtils( stockVariation )( result );
        println@Console( result )();
*/

        if ( is_defined( global.registeredStocks.( stockVariation.name ) )) {
            me -> global.registeredStocks.( stockVariation.name ); // shortcut

            synchronized( syncToken ) {

                oldPrice = me.price;

// aggiorno il prezzo attuale (ricorda che entrambi sono tipi di dato double)
// l'incremento del prezzo potrebbe generare una cifra con un numero di decimali > 2;
// sommo l'incremento al prezzo attuale e successivamente effettuo una arrotondamento a 2 cifre decimali
                priceIncrement = me.price * stockVariation.variation;
                me.price += priceIncrement;
// effettuo l'arrotondamento a 2 decimali
                roundRequest = me.price;
                roundRequest.decimals = 2;
                round@Math( roundRequest )( me.price );

                println@Console( "addStock@Market, " + stockVariation.name + "; prezzo attuale: " + me.price +
                                    "; variation " + stockVariation.variation + "; incremento del prezzo di " + priceIncrement +
                                    " (" + me.price + " * " + stockVariation.variation + "), " +
                                    "da " + oldPrice + " a " + me.price + ")")()
            }
        }
    }
}
