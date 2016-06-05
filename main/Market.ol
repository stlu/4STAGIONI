include "../config/constants.iol"
include "file.iol"
include "../interfaces/commonInterface.iol"
include "../interfaces/stockInterface.iol"
include "../interfaces/playerInterface.iol"

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



init {
    global.status = true; // se true il Market è aperto

// così come suggerito da Stefania, dichiaramo tutte le eccezioni nell'init
// (una dichiarazione cumulativa per tutti i throw invocati in ciascuna operazione);
// qualora sia invece necessario intraprendere comportamenti specifici è bene definire l'install all'interno dello scope
    install(
// lanciata qualora uno stock con lo stesso nome tenti una nuova registrazione
                StockDuplicatedException => throw( StockDuplicatedException ),
// lanciata qualora un player tenti di acquistare uno stock inesistente
                StockUnknownException => throw( StockUnknownException ),
// lanciata qualora si tenti la registrazione di un player già presente
                PlayerDuplicatedException => throw( PlayerDuplicatedException ),
// lanciata qualora il player name non sia registrato
                PlayerUnknownException => throw( PlayerUnknownException )
            )
}



execution { concurrent }

main {

/*
direttamente dalle specifiche del progetto
"registrarsi presso il Market. Gli Stocks si registrano presso il Market col proprio nome (e.g., "Oro", "Grano", "Petrolio")
e il proprio valore totale iniziale."

ricorda la composizione della struttura registeredStocks (su cui è applicabile il dynamic lookup)
registeredStocks.( stockName )[ 0 ].totalPrice

ricorda la composizione della struttura dati con la quale lo stock effettua l'operazione di registrazione
newStock.name
newStock.totalPrice
*/

// operazione esposta agli stocks sulla porta 8001, definita nell'interfaccia StockToMarketCommunicationInterface
    [ registerStock( newStock )( response ) {
// dynamic lookup rispetto alla stringa newStock.name
        if ( ! is_defined( global.registeredStocks.( newStock.name )[ 0 ] )) {

            if ( DEBUG ) {
                valueToPrettyString@StringUtils( newStock )( result );
                println@Console( "\nMarket@registerStock, newStock:" + result )()
            };

            global.registeredStocks.( newStock.name )[ 0 ].totalPrice = newStock.totalPrice;
            global.registeredStocks.( newStock.name )[ 0 ].name = newStock.name;

// TODO: timer correlato all'algoritmo di pricing; funziona correttamente?
            getCurrentTimeMillis@Time(  )( T );
            global.registeredStocks.( newStock.name )[ 0 ].time1 = T;

// TODO: qualora l'operazione sia andata a buon fine risponde true; ma l'operazione è chiaramente andata a buon
// fine, altrimenti viene lanciato un fault. Questa response potrebbe essere superflua.
// si veda registerStock@StockToMarketCommunication all'interno di Stock.ol (ovvero l'invocante)
            response = true
        } else {
            /* esiste uno stock con lo stesso nome è già registrato al market
             * (caso praticamente impossibile visto che StocksDiscoverer presta
             * particolare attenzione al parsing dei nomi dei nuovi stock);
             * ma noi siamo avanti e risolviamo problemi impossibili ;)
             */
            throw( StockDuplicatedException, { .stockName = newStock.name } )
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
// Richiesta in entrata dal Player
    [ registerPlayer( incomingPlayer )( newAccount ) {

        // Caso in cui il Player è nuovo
        if ( ! is_defined( global.accounts.( incomingPlayer ) )) {
            global.accounts.( incomingPlayer ) = incomingPlayer;
            global.accounts.( incomingPlayer ).liquidity = 100;
            newAccount << global.accounts.( incomingPlayer )

        // Caso in cui il player sia già presente, non dovrebbe
        // verificarsi; tuttavia intercetto e rilancio un'eventuale eccezione
        } else {

// TODO: da intercettare all'interno del player
            throw( PlayerDuplicatedException, { .playerName = incomingPlayer })
        }

    } ] {
        if ( DEBUG ) println@Console( "\nregisterPlayer@Market, incomingPlayer: " + incomingPlayer )()
    }

/*
 * Operazione buyStock dell'interfaccia PlayerToMarketCommunicationInterface
 * porta 8000 | Client: Player | Server: Market
 *
 * Responsabilità del Market è di verificare la possibilità dell'acquisto
 * 1) Verificare disponibilità denaro del Player (locale)
 * 2) Verificare disponibilità Stock (deve chiedere allo Stock)
 */
    [ buyStock( transactionRequest )( receipt ) {
        /* 1) */

// TODO: verificare che il player sia correttamente registrato al market, altrimenti lanciare il seguente fault:
// throw( PlayerUnknownException , { .playerName = transactionRequest.player })

        if ( is_defined( global.registeredStocks.(transactionRequest.stock))) {

            if (DEBUG) {
                println@Console( ">>>BUYSTOCK " + transactionRequest.stock +">>> PLAYER: "+ transactionRequest.player +
                    ">>> PLAYER cash: " + global.accounts.(transactionRequest.player).liquidity +
                    ">>> TOTALEPREZZO Stock: " + global.registeredStocks.(transactionRequest.stock).totalPrice )()
            };

            synchronized ( atomicamente ) {

                infoStockAvailability@MarketToStockCommunication( transactionRequest.stock )( availability );
                if (DEBUG) println@Console( ">>>BUYSTOCK availability " + availability )();

                currentPrice = global.registeredStocks.(transactionRequest.stock).totalPrice / availability;
                if (DEBUG) println@Console( ">>>BUYSTOCK currentPrice " + currentPrice )();

                // Inizializza la struttura della receipt
                with( receipt ) {
                    .stock = transactionRequest.stock;
                    .kind = 1;
                    .esito = false;
                    .price = currentPrice
                };

                if ( global.accounts.(transactionRequest.player).liquidity >= currentPrice ) {

                    /* 2) */
                    infoStockAvailability@MarketToStockCommunication( transactionRequest.stock )( availability );
                    if (DEBUG) println@Console( ">>>BUYSTOCK availability " + availability )();

                    if ( availability > 0 ) {
                        // Decremento disponibilità Stock

// TODO: può generare una StockUnknownException; da effettuare il relativo install e, eventualmente,
// rilanciare il fault al player. Risponde con un boolean TRUE qualora l'operazione sia andata a buon fine.
                        buyStock@MarketToStockCommunication( transactionRequest.stock )( response );

                        // Se l'operazione di buyStock è andata a buon fine effettua anche le altre operazioni
                        if (response == true) {
                            //intanto mi prendo il tempo ora per sicurezza, per poi calcolare il prezz0
                            getCurrentTimeMillis@Time(  )( T2 );
                            global.registeredStocks.( transactionRequest.stock )[ 0 ].time2=T2;
                            DELTA=long(global.registeredStocks.( transactionRequest.stock )[ 0 ].time2)-long(global.registeredStocks.( transactionRequest.stock )[ 0 ].time1);
                            //print@Console(global.registeredStocks.( transactionRequest.stock )[ 0 ].name + " , differenza " + " è: " + DELTA + "    ")();
                            global.registeredStocks.( transactionRequest.stock )[ 0 ].time1=  global.registeredStocks.( transactionRequest.stock )[ 0 ].time2;

                            //Incremento quantità stock posseduta dal player
                            //nell'account presso il Market
                            global.accounts.(transactionRequest.player).ownedStock.
                                            (transactionRequest.stock).quantity++;

                            //Decremento denaro nell'account del player presso il
                            //Market
                            global.accounts.(transactionRequest.player).liquidity -= receipt.price;
                            receipt.price = 0 - currentPrice;

                            //  incremento prezzo di 1/disponibilità,ora devi solo aggiungere il fattore tempo ;)
                            priceDecrement = global.registeredStocks.(transactionRequest.stock).totalPrice * (double( 1.0 ) / double( availability ));
                            if (DELTA<1000){
                              priceDecrement += priceDecrement*0.0001
                            };
                            if (DELTA>=1000&&DELTA<2000){
                                priceDecrement += priceDecrement*0.001
                            };
                            if (DELTA>=2000) {
                              priceDecrement += priceDecrement*0.01
                            };
                            // effettuo l'arrotondamento a 5 decimali
                            roundRequest = priceDecrement;
                            roundRequest.decimals = 5;
                            round@Math( roundRequest )( variazionePrezzo );

                            global.registeredStocks.(transactionRequest.stock).totalPrice += variazionePrezzo;
                            if (DEBUG) println@Console(">>>BUYSTOCK incremento prezzo di: "  + variazionePrezzo )();
                            with( receipt ) {
                                .stock = transactionRequest.stock;
                                .kind = 1;
                                .esito = true
                            }
                        } // if (response == true)
                    } // if ( availability > 0 )
                }
            }  //synchronized
        } else {
            // Caso in cui lo Stock richiesto dal Player non esista
            throw( StockUnknownException , { .stockName = transactionRequest.stock })
        }
    } ] { nullProcess }

/*
 * Operazione sellStock dell'interfaccia PlayerToMarketCommunicationInterface
 * porta 8000 | Client: Player | Server: Market
 */
    [ sellStock( transactionRequest )( receipt ) {

// TODO: verificare che il player sia correttamente registrato al market, altrimenti lanciare il seguente fault:
// throw( PlayerUnknownException , { .playerName = transactionRequest.player })

        if ( is_defined( global.registeredStocks.(transactionRequest.stock))) {
            if (DEBUG) println@Console( ">>>SELLSTOCK Stock " + transactionRequest.stock)();

            synchronized ( atomicamente ) {
                /*QUESTO PUNTO è CRITICO, STO INSERENDO UN SYNC AD UN
                  LIVELLO PIUTTOSTO ALTO, DOBBIAMO PARLARNE*/
                infoStockAvailability@MarketToStockCommunication( transactionRequest.stock )( availability );
                if (DEBUG) println@Console( ">>>SELLSTOCK availability " + availability )();

                currentPrice = global.registeredStocks.(transactionRequest.stock).totalPrice / availability;

                // Inizializza la struttura della receipt
                with( receipt ) {
                    .stock = transactionRequest.stock;
                    .kind = 1;
                    .esito = false;
                    .price = currentPrice
                };

                //intanto mi prendo il tempo ora per sicurezza, per poi calcolare il prezz0
                getCurrentTimeMillis@Time(  )( T2 );
                global.registeredStocks.( transactionRequest.stock )[ 0 ].time2=T2;
                DELTA=long(global.registeredStocks.( transactionRequest.stock )[ 0 ].time2)-long(global.registeredStocks.( transactionRequest.stock )[ 0 ].time1);
                //print@Console(global.registeredStocks.( transactionRequest.stock )[ 0 ].name + " , differenza " + " è: " + DELTA + "    ")();
                global.registeredStocks.( transactionRequest.stock )[ 0 ].time1=  global.registeredStocks.( transactionRequest.stock )[ 0 ].time2;

                // Se Player possiede lo stock lo mette in vendita
                if (global.accounts.(transactionRequest.player).ownedStock.
                                                (transactionRequest.stock).quantity > 0) {
                    if (DEBUG) println@Console( ">>>SELLSTOCK quantity > 0 ")();
                    //Incremento disponibilità Stock
                    sellStock@MarketToStockCommunication( transactionRequest.stock )( response );

                    // Se l'operazione di sellStock è andata a buon fine effettua anche le altre operazioni
                    if (response == true) {
                        //Decremento quantità stock posseduta dal player nell'account
                        //presso il Market
                        global.accounts.(transactionRequest.player).ownedStock.
                                                (transactionRequest.stock).quantity--;
                        //Incremento denaro nell'account del player presso il Market
                        global.accounts.(transactionRequest.player).liquidity += currentPrice;

                        //  decremento prezzo di 1/disponibilità,ora devi solo aggiungere il fattore tempo ;)
                        priceIncrement = global.registeredStocks.(transactionRequest.stock).totalPrice * (double( 1.0 ) / double(availability ));
                        if (DELTA < 1000){
                          priceIncrement -= priceDecrement*0.0001
                        };
                        if (DELTA>=1000&&DELTA<2000){
                            priceIncrement -= priceDecrement*0.001
                        };
                        if (DELTA>=2000) {
                          priceIncrement -= priceDecrement*0.01
                        };
                        // effettuo l'arrotondamento a 2 decimali
                        roundRequest = priceIncrement;
                        roundRequest.decimals = 5;
                        round@Math( roundRequest )( variazionePrezzo );

                        global.registeredStocks.(transactionRequest.stock).totalPrice -= variazionePrezzo;
                        if (DEBUG) println@Console( ">>>SELLSTOCK decremento prezzo di: "  + variazionePrezzo )();
                        with( receipt ) {
                            .stock = transactionRequest.stock;
                            .kind = -1;
                            .esito = true
                        }
                    } // response
                } // quantity > 0
            } // syncronized
        } else {
            // Caso in cui lo Stock richiesto dal Player non esista
            throw( StockUnknownException , { .stockName = transactionRequest.stock })
        }
    } ] { nullProcess }



// operazione invocata dal Player; restituisce la lista degli stock registrati, attualmente presenti
    [ infoStockList( info )( responseInfo ) {
        i = 0;
        foreach ( stockName : global.registeredStocks ) {
            responseInfo.name[i] = global.registeredStocks.(stockName).name;
            i = i + 1
        }
    } ] { nullProcess }



// operazione invocata dal Player; restituisce il prezzo corrente di uno specifico stock (double)
    [ infoStockPrice( stockName )( responsePrice ) {
        if ( DEBUG ) println@Console( ">>>infoStockPrice nome "  + stockName )();

        infoStockAvailability@MarketToStockCommunication( stockName )( availability );

        if ( is_defined( global.registeredStocks.( stockName ) )) {
            responsePrice = global.registeredStocks.( stockName ).totalPrice / availability
        } else {
            // Caso in cui lo Stock richiesto dal Player non esista
            throw( StockUnknownException, { .stockName = stockName })
        }
    } ] { nullProcess }



// operazione invocata dal Player; restituisce l'informazione availability correlata allo stock richiesto
    [ infoStockAvailability( stockName )( responseAvailability ) {
        if ( is_defined( global.registeredStocks.( stockName ) )) {
            infoStockAvailability@MarketToStockCommunication( stockName )( responseAvailability )
        } else {
// caso in cui lo Stock richiesto dal Player non esista
            throw( StockUnknownException, { .stockName = stockName })
        }
    } ] { nullProcess }



    /* Verifica lo stato del market */
    [ checkMarketStatus( )( responseStatus ) {
        if (global.status) {
            responseStatus = true;
            responseStatus.message = "Market Open"
        } else {
            responseStatus = false;
            responseStatus.message = "Market Closed"
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

                oldPrice = me.totalPrice;

// aggiorno il prezzo attuale (ricorda che entrambi sono tipi di dato double)
// l'incremento del prezzo potrebbe generare una cifra con un numero di decimali > 2;
// sommo l'incremento al prezzo attuale e successivamente effettuo una arrotondamento a 5 cifre decimali
                priceIncrement = me.totalPrice * stockVariation.variation;
                me.totalPrice += priceIncrement;
// effettuo l'arrotondamento a 2 decimali
                roundRequest = me.totalPrice;
                roundRequest.decimals = 5;
                round@Math( roundRequest )( me.totalPrice );

                if ( DEBUG ) println@Console( "destroyStock@Market, " + stockVariation.name + "; prezzo attuale: " + me.totalPrice +
                                            "; variation " + stockVariation.variation + "; incremento del prezzo di " + priceDecrement +
                                            "(" + me.totalPrice + " * " + stockVariation.variation + "), " +
                                            "da " + oldPrice + " a " + me.totalPrice + ")")()
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

                oldPrice = me.totalPrice;

// aggiorno il prezzo attuale (ricorda che entrambi sono tipi di dato double)
// il decremento del prezzo potrebbe generare una cifra con un numero di decimali > 2;
// sottraggo il decremento al prezzo attuale e successivamente effettuo una arrotondamento a 5 cifre decimali
                priceDecrement = me.totalPrice * stockVariation.variation;
                me.totalPrice -= priceDecrement;
// effettuo l'arrotondamento a 2 decimali
                roundRequest = me.totalPrice;
                roundRequest.decimals = 5;
                round@Math( roundRequest )( me.totalPrice );

// TODO
// che succede se il prezzo diventa < 0? (caso poco probabile ma possibile!)
// forse sarebbe opportuno utilizzare una RequestResponse e, qualora il decremento del prezzo non sia possibile,
// non procedere con il deperimento della quantità di stock; oppure continuare ad usare una OneWay ma prevedere
// il lancio di un fault

                if ( DEBUG ) println@Console( "addStock@Market, " + stockVariation.name + "; prezzo attuale: " + me.totalPrice +
                                            "; variation " + stockVariation.variation + "; decremento del prezzo di " + priceIncrement +
                                            "(" + me.totalPrice + " * " + stockVariation.variation + "), " +
                                            "da " + oldPrice + " a " + me.totalPrice + ")")()
            }
        }
    }
}
