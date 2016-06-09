include "../config/constants.iol"
include "file.iol"
include "../interfaces/commonInterface.iol"
include "../interfaces/stockInterface.iol"
include "../interfaces/playerInterface.iol"

include "console.iol"
include "time.iol"
include "string_utils.iol"
include "math.iol"

// http://docs.jolie-lang.org/#!documentation/jsl/SemaphoreUtils.html
// a differenza di synchronized, è possibile associare una specifica label al semaforo;
// la label equivale al nome dello stock; prevengo quindi l'acquisto | vendita simultanea dello stesso stock
// ma non di stock differenti
include "semaphore_utils.iol"



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



// utile funzione di supporto all'arrotondamento
// ("prende in input" toRound, "restituisce" roundedValue)
define round {
    roundRequest = toRound;
    roundRequest.decimals = DECIMAL_ROUNDING;
    round@Math( roundRequest )( roundedValue )
}

// le seguenti define snelliscono il codice all'interno di buyStock e sellStock ed offrono:
// gestione del timing e algoritmo di pricing
define timeCalc {

// estraggo il tempo tempo corrente
    getCurrentTimeMillis@Time(  )( T2 );
    currentStock.time2 = T2;

// calcolo la differenza rispetto al tempo precedente (DELTA)
    DELTA = long( currentStock.time2 ) - long( currentStock.time1 );
    currentStock.time1 = currentStock.time2;

    if ( DEBUG )
        println@Console( ">>> BUYSTOCK || SELLSTOCK; timeCalc, " + currentStock.name + ", differenza timer " + DELTA )()
}

define priceDec {
// calcolo il prezzo unitario a partire dal prezzo totale (prezzo totale / numero di stock)
    price = currentStock.totalPrice * ( double( 1.0 ) / double( availability ));

// applico l'algoritmo di pricing, rispetto al tempo intercorso dalla precedente operazione
    if ( DELTA < 1000 ) {
        price -= price * 0.0001
    } else if ( DELTA >= 1000 && DELTA < 2000 ) {
        price -= price * 0.001
    } else { // (DELTA >= 2000)
        price -= price * 0.01
    };

    toRound = price; round; priceVariation = roundedValue
}

define priceInc {
// calcolo il prezzo unitario    
    price = currentStock.totalPrice * ( double( 1.0 ) / double( availability ));

    if ( DELTA < 1000 ) {
        price += price * 0.0001
    } else if ( DELTA >= 1000 && DELTA < 2000 ) {
        price += price * 0.001
    } else { // (DELTA >= 2000)
        price += price * 0.01
    };

    toRound = price; round; priceVariation = roundedValue
}



// shortcut per il release del semaforo associato allo stock
define releaseSemaphore {
    toRelease -> global.registeredStocks.( stockName )[ 0 ].semaphore;
    release@SemaphoreUtils( toRelease )( response )
}

// creo un semaforo per lo stock (all'interno della struttura dati degli stock registrati);
// sarà utile per sincronizzare l'accesso alle operazioni di: buy | sell | addStock | destroyStock
define createSemaphore {
    with( global.registeredStocks.( stockName )[ 0 ].semaphore ) {
            .name = stockName;
            .permits = 1
        };
// effettuo una release: devo produrre almeno un token da acquisire
    releaseSemaphore
}



init {
    global.status = true; // se true il Market è aperto

// così come suggerito da Stefania, dichiaramo tutte le eccezioni nell'init
// (una dichiarazione cumulativa per tutti i throw invocati in ciascuna operazione);
// qualora sia invece necessario intraprendere comportamenti specifici è bene definire l'install all'interno dello scope
    install(
// uno stock con lo stesso nome tente una nuova registrazione
                StockDuplicatedException => throw( StockDuplicatedException ),
// un player tenta di acquistare uno stock inesistente
                StockUnknownException => throw( StockUnknownException ),
// lo stock ha terminato la sua disponibilità
                StockAvailabilityException => throw( StockAvailabilityException ),
// registrazione di un player già presente
                PlayerDuplicatedException => throw( PlayerDuplicatedException ),
// player name non registrato
                PlayerUnknownException => throw( PlayerUnknownException ),
// liquidità del player terminata
                InsufficientLiquidityException => throw( InsufficientLiquidityException ),
// il player non dispone dello stock che sta tentando di vendere
                NotOwnedStockException => throw ( NotOwnedStockException )
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
            me -> global.registeredStocks.( newStock.name )[ 0 ];
            me.name = newStock.name;

// TODO: timer correlato all'algoritmo di pricing; funziona correttamente?
// Pekyntosh: beh, sembra proprio di si...            
            getCurrentTimeMillis@Time()( T1 );
            me.time1 = T1;

// TODO: qualora l'operazione sia andata a buon fine risponde true; ma l'operazione è chiaramente andata a buon
// fine, altrimenti viene lanciato un fault. Questa response potrebbe essere superflua.
// si veda registerStock@StockToMarketCommunication all'interno di Stock.ol (ovvero l'invocante)
            response = true;

// creo un semaforo per lo stock; sarà utile per sincronizzare l'accesso alle operazioni di:
// buy | sell | addStock | destroyStock
            stockName = newStock.name;
            createSemaphore

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
            global.accounts.( incomingPlayer ).liquidity = double( DEFAULT_PLAYER_LIQUIDITY );
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

// 2 utili shortcuts
        currentPlayer -> global.accounts.( transactionRequest.player )[ 0 ];
        currentStock -> global.registeredStocks.( transactionRequest.stock )[ 0 ];

// lancio un fault qualora il player non sia correttamente registrato
        if ( ! is_defined( currentPlayer )) {
            with( exceptionMessage ){
                .playerName = transactionRequest.player
            };
            throw( PlayerUnknownException, exceptionMessage )
        };

// lancio un fault qualora lo stock richiesto non sia correttamente registrato
        if ( ! is_defined( currentStock )) {
            with( exceptionMessage ) { .stockName = transactionRequest.stock };
            throw( StockUnknownException, exceptionMessage )
        };

        scope( buyStockScope ) {

// qualora siano invocate le seguenti eccezioni, prima di rilanciarle è indispensabile rilasciare il semaforo
// (saranno poi catturate nell'init e rilanciate ai rispettivi invocanti)
            install(

// un player tenta di acquistare uno stock inesistente (rilanciata dallo stock)
                    StockUnknownException =>    stockName = buyStockScope.StockUnknownException.stockName;
                                                releaseSemaphore;
                                                throw( StockUnknownException, buyStockScope.StockUnknownException ),
// lo stock ha terminato la sua disponibilità                
                    StockAvailabilityException =>   stockName = buyStockScope.StockAvailabilityException.stockName;
                                                    releaseSemaphore;
                                                    throw( StockAvailabilityException, buyStockScope.StockAvailabilityException ),
// liquidità del player terminata
                    InsufficientLiquidityException =>   stockName = buyStockScope.InsufficientLiquidityException.stockName;
                                                        releaseSemaphore;
                                                        throw( InsufficientLiquidityException, buyStockScope.InsufficientLiquidityException )
                );

            acquire@SemaphoreUtils( currentStock.semaphore )( response );
/*
            valueToPrettyString@StringUtils( currentStock.semaphore )( result );
            println@Console( result )();
*/
            if ( DEBUG )
                println@Console( ">>> BUYSTOCK acquisito semaforo per lo stock " + transactionRequest.stock )();

            if ( DEBUG ) {
                    println@Console( ">>> BUYSTOCK " + transactionRequest.stock + " >>> PLAYER: " + transactionRequest.player +
                        " >>> PLAYER cash: " + currentPlayer.liquidity +
                        " >>> TOTALEPREZZO Stock: " + currentStock.totalPrice )()
            };

// richiedo la quantità disponibile per lo stock
// è lanciato un fault qualora la disponibilità sia esaurita
            infoStockAvailability@MarketToStockCommunication( transactionRequest.stock )( availability );
            if ( availability <= 0) {
                with( exceptionMessage ) { .stockName = transactionRequest.stock };
                throw( StockAvailabilityException, exceptionMessage )
            };

            if ( DEBUG ) println@Console( ">>> BUYSTOCK availability " + availability )();

// calcolo il prezzo unitario
            currentPrice = currentStock.totalPrice / availability;
            toRound = currentPrice; round; currentPrice = roundedValue;
            if ( DEBUG ) println@Console( ">>> BUYSTOCK currentPrice " + currentPrice )();

// lancio un fault qualora la liquidità del player non sia sufficiente per procedere con la transazione
            if ( currentPlayer.liquidity < currentPrice ) {
                with( exceptionMessage ) {
                    .stockName = currentStock.name;
                    .currentLiquidity = currentPlayer.liquidity;
                    .neededLiquidity = currentPrice
                };
                throw( InsufficientLiquidityException, exceptionMessage )
            };

// può generare StockUnknownException || StockAvailabilityException;
// risponde con un boolean TRUE qualora l'operazione sia andata a buon fine;
// (1) l’unità di Stock disponibile viene decrementata di 1
            buyStock@MarketToStockCommunication( transactionRequest.stock )( response );
// Se l'operazione di buyStock è andata a buon fine effettua anche le altre operazioni
//            if ( response ) {
// è chiaro che l'operazione sia andata a buon fine; altrimenti è sollevato un fault

// (2) si aumenta di 1 la quantità di Stock posseduto dal Player acquirente
            currentPlayer.ownedStock.( transactionRequest.stock ).quantity++;

// (3) si decrementa l’Account del Player dell’attuale prezzo di un’unità di Stock
            currentPlayer.liquidity -= currentPrice;
            toRound = currentPlayer.liquidity; round; currentPlayer.liquidity = roundedValue;

// (4) si aumenta il prezzo totale di quello Stock in maniera corrispondente a quanto riportato in...
// incremento il prezzo totale rispetto alla variazione calcolata dall'algoritmo di pricing (define priceInc)
            timeCalc; priceInc; // algoritmo di pricing
            currentStock.totalPrice += priceVariation;
            toRound = currentStock.totalPrice; round; currentStock.totalPrice = roundedValue;

            if ( DEBUG ) println@Console(">>> BUYSTOCK incremento prezzo di: " + priceVariation )();

// Inizializza la struttura della receipt
            with( receipt ) {
                .stock = transactionRequest.stock;
                .kind = 1;
                .esito = true;
                .price = 0 - currentPrice
            };

// TO REMOVE, for debug purpose only =)
//            println@Console( "Aspetto 3 secondi prima di rilasciare il semaforo su " + transactionRequest.stock )();
//            sleep@Time( 3000 )();
            release@SemaphoreUtils( currentStock.semaphore )( response )
        }

    } ] { nullProcess }




/*
 * Operazione sellStock dell'interfaccia PlayerToMarketCommunicationInterface
 * porta 8000 | Client: Player | Server: Market
 */
    [ sellStock( transactionRequest )( receipt ) {

// 2 utili shortcuts
        currentPlayer -> global.accounts.( transactionRequest.player )[ 0 ];
        currentStock -> global.registeredStocks.( transactionRequest.stock )[ 0 ];

// lancio un fault qualora il player non sia correttamente registrato
        if ( ! is_defined( currentPlayer )) {
            with( exceptionMessage ){
                .playerName = transactionRequest.player
            };
            throw( PlayerUnknownException, exceptionMessage )
        };

// lancio un fault qualora lo stock richiesto non sia correttamente registrato
        if ( ! is_defined( currentStock )) {
            with( exceptionMessage ) { .stockName = transactionRequest.stock };
            throw( StockUnknownException, exceptionMessage )
        };



        scope( sellStockScope ) {

// qualora siano invocate le seguenti eccezioni, prima di rilanciarle è indispensabile rilasciare il semaforo
// (saranno poi catturate nell'init e rilanciate ai rispettivi invocanti)   
            install(

// un player tenta di acquistare uno stock inesistente (rilanciata dallo stock)
                    StockUnknownException =>    stockName = sellStockScope.StockUnknownException.stockName;
                                                releaseSemaphore;
                                                throw( StockUnknownException, sellStockScope.StockUnknownException ),

// un player tenta di vendere uno stock che non possiede
                    NotOwnedStockException =>   stockName = sellStockScope.NotOwnedStockException.stockName;
                                                releaseSemaphore;
                                                throw( NotOwnedStockException, sellStockScope.NotOwnedStockException )
                );

// http://docs.jolie-lang.org/#!documentation/jsl/SemaphoreUtils.html
// a differenza di synchronized, è possibile associare una specifica label al semaforo;
// la label equivale al nome dello stock; prevengo quindi l'acquisto | vendita simultanea dello stesso stock
// ma non di stock differenti
            acquire@SemaphoreUtils( currentStock.semaphore )( response );
/*
            valueToPrettyString@StringUtils( currentStock.semaphore )( result );
            println@Console( result )();
*/
            if ( DEBUG )
                println@Console( ">>> SELLSTOCK acquisito semaforo per lo stock " + transactionRequest.stock )();

            currentPlayer -> global.accounts.( transactionRequest.player )[ 0 ];

// il player dispone dello stock che vuol vendere?
            if ( ! is_defined( currentPlayer.ownedStock.( transactionRequest.stock ) ) || 
                ( currentPlayer.ownedStock.( transactionRequest.stock ).quantity <= 0 ) ) {
                with( exceptionMessage ) { .stockName = transactionRequest.stock };
                throw( NotOwnedStockException, exceptionMessage )
            };

// richiedo la quantità disponibile per lo stock
            infoStockAvailability@MarketToStockCommunication( transactionRequest.stock )( availability );
// qualora la disponbilità sia esaurita o pari a 1, il prezzo unitario corrisponderà al prezzo totale            
            if ( availability <= 1 ) {
                currentPrice = currentStock.totalPrice
            } else {
// calcolo il prezzo unitario
                currentPrice = currentStock.totalPrice / availability;
                toRound = currentPrice; round; currentPrice = roundedValue
            };

// può generare StockUnknownException 
// risponde con un boolean TRUE qualora l'operazione sia andata a buon fine;
// (1) l’unità di Stock disponibile viene incrementata di 1
            sellStock@MarketToStockCommunication( transactionRequest.stock )( response );
// Se l'operazione di sellStock è andata a buon fine effettua anche le altre operazioni
//            if ( response ) {
// è chiaro che l'operazione sia andata a buon fine; altrimenti è sollevato un fault

// (2) si decrementa di 1 la quantità di Stock posseduto dal Player venditore;
            currentPlayer.ownedStock.( transactionRequest.stock ).quantity--;

// (3) si incrementa l’Account del Player dell’attuale prezzo di un’unità di Stock
            currentPlayer.liquidity += currentPrice;
            toRound = currentPlayer.liquidity; round; currentPlayer.liquidity = roundedValue;
            if ( DEBUG ) println@Console( ">>> SELLSTOCK current price " + currentPrice )();

// (4) si diminuisce il prezzo totale dello Stock in maniera corrispondente a quanto riportato in...
// decremento il prezzo totale rispetto alla variazione calcolata dall'algoritmo di pricing (define priceDec)
            timeCalc; priceDec; // algoritmo di pricing
            currentStock.totalPrice -= priceVariation;
            toRound = currentStock.totalPrice; round; currentStock.totalPrice = roundedValue;

            if ( DEBUG ) println@Console(">>> SELLSTOCK decremento il prezzo di: " + priceVariation )();

// Inizializza la struttura della receipt
            with( receipt ) {
                .stock = transactionRequest.stock;
                .kind = -1;
                .esito = true;
                .price = currentPrice
            };

// TO REMOVE, for debug purpose only =)
//            println@Console( "Aspetto 3 secondi prima di rilasciare il semaforo su " + transactionRequest.stock )();
//            sleep@Time( 3000 )();
            release@SemaphoreUtils( currentStock.semaphore )( response )
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
//    
// TODO: a me 'sta cosa non convince un granchè. Sto effettuando dei calcoli su totalPrice senza alcun tipo
// di "protezione" sull'accesso alla risorsa condivisa. E se contemporaneamente il prezzo subisse
// una qualche modifica a seguito di un'operazione di acquisto | vendita? uhmm..
    [ infoStockPrice( stockName )( responsePrice ) {
        if ( DEBUG ) println@Console( ">>> infoStockPrice nome "  + stockName )();

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
    [ destroyStock( stockVariation ) ] {

/*
        valueToPrettyString@StringUtils( stockVariation )( result );
        println@Console( result )();
*/

        if ( ! is_defined( global.registeredStocks.( stockVariation.name ) ))
            throw( StockUnknownException, { .stockName = stockName });

        me -> global.registeredStocks.( stockVariation.name ); // shortcut

        acquire@SemaphoreUtils( me.semaphore )();

        oldPrice = me.totalPrice;
// aggiorno il prezzo attuale (ricorda che entrambi sono tipi di dato double)
// sommo l'incremento al prezzo attuale e successivamente effettuo l'arrotondamento
        priceIncrement = me.totalPrice * stockVariation.variation;
        me.totalPrice += priceIncrement;
        toRound = me.totalPrice; round; me.totalPrice = roundedValue;

        if ( DEBUG ) println@Console( "destroyStock@Market, " + stockVariation.name + "; prezzo attuale: " + me.totalPrice +
                                    "; variation " + stockVariation.variation + "; incremento del prezzo di " + priceIncrement +
                                    " (" + me.totalPrice + " * " + stockVariation.variation + "), " +
                                    "da " + oldPrice + " a " + me.totalPrice + ")")();
        
        release@SemaphoreUtils( me.semaphore )()

    }



// riceve i quantitativi prodotti da parte di ciascun stock; le richieste sono strutturate secondo StockVariationStruct
// (.name, .variation) definita all'interno di stockInterface.iol
// è stata prodotta una quantità di stock, addStock rettifica il prezzo;
// dato che la quantità è aumentata, il prezzo diminuisce
    [ addStock( stockVariation ) ] {

/*
        valueToPrettyString@StringUtils( stockVariation )( result );
        println@Console( result )();
*/

        if ( ! is_defined( global.registeredStocks.( stockVariation.name ) ))
            throw( StockUnknownException, { .stockName = stockName });

        me -> global.registeredStocks.( stockVariation.name ); // shortcut

        acquire@SemaphoreUtils( me.semaphore )();

// da specifiche: "il prezzo di uno Stock non può mai scendere sotto il valore di 10;"

// aggiorno il prezzo attuale (ricorda che entrambi sono tipi di dato double)
// sottraggo il decremento al prezzo attuale e successivamente effettuo l'arrotondamento
// scelta progettuale (da documentare):
// qualora il prezzo risultante dal decremento sia < 10, imposto il prezzo a 10 ed evito ulteriori decrementi
        if ( me.totalPrice > MINIMUN_STOCK_PRICE ) {
            oldPrice = me.totalPrice;
            priceDecrement = me.totalPrice * stockVariation.variation;
            if ( ( me.totalPrice - priceDecrement ) <= MINIMUN_STOCK_PRICE ) {
                me.totalPrice = double( MINIMUN_STOCK_PRICE )
            } else {
                me.totalPrice -= priceDecrement;
                toRound = me.totalPrice; round; me.totalPrice = roundedValue
            }
        };

        if ( DEBUG ) println@Console( "addStock@Market, " + stockVariation.name + "; prezzo attuale: " + me.totalPrice +
                                    "; variation " + stockVariation.variation + "; decremento del prezzo di " + priceDecrement +
                                    " (" + me.totalPrice + " * " + stockVariation.variation + "), " +
                                    "da " + oldPrice + " a " + me.totalPrice + ")")();

        release@SemaphoreUtils( me.semaphore )()

    }
}