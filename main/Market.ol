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
            if (DEBUG) println@Console( "\nMarket@registerStock, newStock:" + result )();
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
            global.accounts.(incomingPlayer) = incomingPlayer;
            global.accounts.(incomingPlayer).liquidity = 100;
            newAccount << global.accounts.(incomingPlayer)
        //Caso in cui il player fosse già presente, non dovrebbe
        //verificarsi
        } else {
            throw( PlayerDuplicateException )
        }
    } ] {
        if (DEBUG) println@Console( "\nregisterPlayer@Market, incomingPlayer: "
        + incomingPlayer )()
    }

/*
 * Operazione buyStock dell'interfaccia PlayerToMarketCommunicationInterface
 * porta 8000 | Client: Player | Server: Market
 *
 * Responsabilità del Market è di verificare la possibilità dell'acquisto
 * 1) Verificare disponibilità denaro del Player (locale)
 * 2) Verificare disponibilità Stock (deve chiedere allo Stock)
 */
    [ buyStock( TransactionRequest )( Receipt ) {
        /* 1) */
        if ( is_defined( global.registeredStocks.(TransactionRequest.stock))) {

            if (DEBUG) {
                println@Console( ">>>BUYSTOCK PLAYER cash " + global.accounts.(TransactionRequest.player).liquidity )();
                println@Console( ">>>BUYSTOCK Costo Stock " + global.registeredStocks.(TransactionRequest.stock).price )()
            };

            if ( global.accounts.(TransactionRequest.player).liquidity
                <
                global.registeredStocks.(TransactionRequest.stock).price) {
                    with( Receipt ) {
                        .stock = TransactionRequest.stock;
                        .kind = 1;
                        .esito = false;
                        .price = global.registeredStocks.
                                            (TransactionRequest.stock).price
                    }
            } else {
                /*QUESTO PUNTO è CRITICO, STO INSERENDO UN SYNC AD UN
                  LIVELLO PIUTTOSTO ALTO, DOBBIAMO PARLARNE*/
                synchronized ( atomicamente ) {
                    /* 2) */
                    infoStockAvailability@MarketToStockCommunication
                    ( TransactionRequest.stock )( availability );
                    if (DEBUG) println@Console( ">>>BUYSTOCK availability " + availability )();

                    if ( availability > 0 ) {
                        //Decremento disponibilità Stock
                        buyStock@MarketToStockCommunication
                                    ( TransactionRequest.stock )( response );

                        //Incremento quantità stock posseduta dal player
                        //nell'account presso il Market
                        global.accounts.(TransactionRequest.player).ownedStock.
                                        (TransactionRequest.stock).quantity++;

                        //Decremento denaro nell'account del player presso il
                        //Market
                        global.accounts.(TransactionRequest.player).liquidity
                        -=
                        global.registeredStocks.(TransactionRequest.stock).price;
                        Receipt.price = 0 - global.registeredStocks.
                                            (TransactionRequest.stock).price;

                        //  incremento prezzo di 1/disponibilità,ora devi solo aggiungere il fattore tempo ;)
                        priceDecrement = global.registeredStocks.(TransactionRequest.stock).price * (double( 1.0 ) / double( availability ));
                        // effettuo l'arrotondamento a 2 decimali
                        roundRequest = priceDecrement;
                        roundRequest.decimals = 2;
                        round@Math( roundRequest )( variazionePrezzo);
                        global.registeredStocks.(TransactionRequest.stock).price += priceDecrement;
                        if (DEBUG) println@Console(">>>BUYSTOCK incremento prezzo di: "  + variazionePrezzo )()
                    };
                    with( Receipt ) {
                        .stock = TransactionRequest.stock;
                        .kind = 1;
                        .esito = true
                    }
                }
            }
        } else {
            // Caso in cui lo Stock richiesto dal Player non esista
            throw( StockUnknownException )
        }
    } ] { nullProcess }

/*
 * Operazione sellStock dell'interfaccia PlayerToMarketCommunicationInterface
 * porta 8000 | Client: Player | Server: Market
 */
    [ sellStock( TransactionRequest )( Receipt ) {
        if ( is_defined( global.registeredStocks.(TransactionRequest.stock))) {
            /*QUESTO PUNTO è CRITICO, STO INSERENDO UN SYNC AD UN
              LIVELLO PIUTTOSTO ALTO, DOBBIAMO PARLARNE*/
              infoStockAvailability@MarketToStockCommunication
              ( TransactionRequest.stock )( availability );
            synchronized ( atomicamente ) {
                //Incremento disponibilità Stock
                sellStock@MarketToStockCommunication( TransactionRequest.stock )
                                                                ( response );
                //Decremento quantità stock posseduta dal player nell'account
                //presso il Market
                global.accounts.(TransactionRequest.player).ownedStock.
                                        (TransactionRequest.stock).quantity--;
                //Incremento denaro nell'account del player presso il Market
                global.accounts.(TransactionRequest.player).liquidity
                +=
                global.registeredStocks.(TransactionRequest.stock).price;
                Receipt.price = global.registeredStocks.
                                            (TransactionRequest.stock).price;


                //  decremento prezzo di 1/disponibilità,ora devi solo aggiungere il fattore tempo ;)
                priceIncrement = global.registeredStocks.(TransactionRequest.stock).price * (double( 1.0 ) / double(availability ));
                // effettuo l'arrotondamento a 2 decimali
                roundRequest = priceIncrement;
                roundRequest.decimals = 2;
                round@Math( roundRequest )( variazionePrezzo);
                global.registeredStocks.(TransactionRequest.stock).price -= priceIncrement;
                if (DEBUG) println@Console( ">>>SELLSTOCK decremento prezzo di: "  + variazionePrezzo )()

            };
            with( Receipt ) {
                .stock = TransactionRequest.stock;
                .kind = -1;
                .esito = true
            }
        } else {
            // Caso in cui lo Stock richiesto dal Player non esista
            throw( StockUnknownException )
        }
    } ] { nullProcess }

    [ infoStockList( info )( responseInfo ) {
        i=0;
        foreach ( stockName : global.registeredStocks ) {
            responseInfo.name[i]=string( global.registeredStocks.(stockName).name);
            i=i+1
        }
    } ] { nullProcess }

    [ infoStockPrice( stockName )( responsePrice ) {
        if (DEBUG) println@Console( ">>>infoStockPrice nome"  + stockName )();
      if ( is_defined( global.registeredStocks.( stockName ) )) {
          responsePrice=global.registeredStocks.( stockName ).price
      } else {
          // Caso in cui lo Stock richiesto dal Player non esista
          throw( StockUnknownException )
      }
    } ] { nullProcess }

    [ infoStockAvailability( stockName )( responseAvailability ) {
        if ( is_defined( global.registeredStocks.( stockName ))) {
            infoStockAvailability@MarketToStockCommunication( stockName )( responseAvailability )
        } else {
            // Caso in cui lo Stock richiesto dal Player non esista
            throw( StockUnknownException )
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
// si è deperità una quantità di stock, destroyStock rettifica il prezzo;
// dato che la quantità è diminuita, il prezzo aumenta
    [ destroyStock( stockVariation )] {

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

                if (DEBUG) println@Console( "destroyStock@Market, " + stockVariation.name + "; prezzo attuale: " + me.price +
                                            "; variation " + stockVariation.variation + "; incremento del prezzo di " + priceDecrement +
                                            "(" + me.price + " * " + stockVariation.variation + "), " +
                                            "da " + oldPrice + " a " + me.price + ")")()
            }
        }
    }



// riceve i quantitativi prodotti da parte di ciascun stock; le richieste sono strutturate secondo StockVariationStruct
// (.name, .variation) definita all'interno di stockInterface.iol
// è stata prodotta una quantità di stock, addStock rettifica il prezzo;
// dato che la quantità è aumentata, il prezzo diminuisce
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
// non procedere con il deperimento della quantità di stock; oppure continuare ad usare una OneWay ma prevedere
// il lancio di un fault

                if (DEBUG) println@Console( "addStock@Market, " + stockVariation.name + "; prezzo attuale: " + me.price +
                                            "; variation " + stockVariation.variation + "; decremento del prezzo di " + priceIncrement +
                                            "(" + me.price + " * " + stockVariation.variation + "), " +
                                            "da " + oldPrice + " a " + me.price + ")")()
            }
        }
    }
}
