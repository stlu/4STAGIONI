include "../config/constants.iol"
include "../interfaces/commonInterface.iol"
include "../interfaces/playerInterface.iol"

include "console.iol"
include "time.iol"
include "runtime.iol"
include "string_utils.iol"
include "math.iol"

/*
 * Il valore della costante viene sovrascritto lanciando Player.ol con:
 *
 *      jolie -C Player_Name=\"Johnny\" Player.ol
 */
constants {
    Player_Name1 = "Player1",
    Player_Name2 = "Player2",
    Frequence = 5000
}

outputPort PlayerToMarketCommunication {
    Location: "socket://localhost:8002"
    Protocol: sodep
    Interfaces: PlayerToMarketCommunicationInterface, MarketCommunicationInterface
}

// definizioni di interfaccia e outputPort per un'invocazione "riflessiva"
interface LocalInterface {
    OneWay: registration2player( void ) // registrazione del player presso il market
    OneWay: run2player( void )
}
inputPort LocalInputPort {
    Location: "local"
    Interfaces: LocalInterface
}
outputPort Self { Interfaces: LocalInterface }

init {
    // Imposta la location della output port Self per comunicare con le operazioni esposte in LocalInterface
    getLocalLocation@Runtime()( Self.location );
    registration2player@Self();    // registra due player

    install (
        //  market è down errore irreversibile,interrompo l'esecuzione del programma
            IOException =>                      println@Console( MARKET_DOWN_EXCEPTION )();
                                                valueToPrettyString@StringUtils( global.status1 )( result );
                                                println@Console( "Player1 " + result )();
                                                valueToPrettyString@StringUtils( global.status2 )( result );
                                                println@Console( "Player2 " + result )();halt@Runtime()(),

        // il player name è già in uso interrompe esecuzione
            PlayerDuplicatedException =>        valueToPrettyString@StringUtils(  main.PlayerDuplicatedException )( result );
                                                println@Console( "PlayerDuplicatedException\n" + result )(); halt@Runtime()(),

        // il player sta tentando di effettuare una transazione, ma non si è correttamente registrato presso il market
            PlayerUnknownException =>           valueToPrettyString@StringUtils(  main.PlayerUnknownException )( result );
                                                println@Console( "PlayerUnknownException\n" + result )(); halt@Runtime()(),

        // lo stock ha terminato la sua disponibilità
            StockAvailabilityException =>       valueToPrettyString@StringUtils(  main.StockAvailabilityException )( result );
                                                println@Console( "StockAvailabilityException\n" + result )();
                                                run2player@Self(),
        // il player tenta di acquistare uno stock inesistente
            StockUnknownException =>            valueToPrettyString@StringUtils(  main.StockUnknownException )( result );
                                                println@Console( "StockUnknownException\n" + result )();
                                                run2player@Self(),
        // liquidità del player terminata
            InsufficientLiquidityException =>   valueToPrettyString@StringUtils(  main.InsufficientLiquidityException )( result );
                                                println@Console( "InsufficientLiquidityException\n" + result )();
                                                run2player@Self(),
        // il player non dispone dello stock che sta tentando di vendere
            NotOwnedStockException =>           valueToPrettyString@StringUtils(  main.NotOwnedStockException )( result );
                                                println@Console( "NotOwnedStockException\n" + result )();
                                                run2player@Self()
    )
}

// Raccoglie le informazioni sugli stock attivi e il loro prezzo
// e li memorizza nelle strutture stock1 e stock2 una per ogni utente
define infoStockList {
    infoStockList@PlayerToMarketCommunication( "info" )( responseInfo );
    for ( k = 0, k < #responseInfo.name, k++ ) {
        stockName=responseInfo.name[k];
        infoStockPrice@PlayerToMarketCommunication( stockName )( responsePrice );
        if ( ! is_defined( StockAllowed.(stockName).price )){
          StockAllowed.(stockName).price=responsePrice
        }
    };
    global.stocks1 << StockAllowed;
    global.stocks2 << StockAllowed
}

// operazioni player1
define buy1 {
    buyStock@PlayerToMarketCommunication( nextBuy1 )( receipt );
    if(receipt.esito == true) {
        global.status1.ownedStock.(receipt.stock).quantity += receipt.kind;
        global.status1.liquidity += receipt.price
    }
}
define sell1 {
    sellStock@PlayerToMarketCommunication( nextSell1 )( receipt );
    if(receipt.esito == true) {
        global.status1.ownedStock.(receipt.stock).quantity += receipt.kind;
        global.status1.liquidity += receipt.price
    }
}
// operazioni player2
define buy2 {
    buyStock@PlayerToMarketCommunication( nextBuy2 )( receipt );
    if(receipt.esito == true) {
        global.status2.ownedStock.(receipt.stock).quantity += receipt.kind;
        global.status2.liquidity += receipt.price
    }
}
define sell2 {
    sellStock@PlayerToMarketCommunication( nextSell2 )( receipt );
    if(receipt.esito == true) {
        global.status2.ownedStock.(receipt.stock).quantity += receipt.kind;
        global.status2.liquidity += receipt.price
    }
}
define randGenStock {
// Returns a random number d such that 0.0 <= d < 1.0.
    random@Math()( rand );
    rand=rand*100;
// genera un valore random, estremi inclusi
    gen=int(rand % (#responseInfo.name));
    stockName=responseInfo.name[gen]
}


execution { concurrent }


main {

    // registrazione del player sul market; intercetta eccezioni e gestisce i tentativi di connessione
    [ registration2player() ] {

        install(
            // se il player tenta la registrazione ed il market è down errore irreversibile,
            // interrompo l'esecuzione del programma
            IOException => println@Console( MARKET_DOWN_EXCEPTION )(); halt@Runtime()(),

            // se il player tenta la registrazione ed il market è chiuso, riesegue ciclicamente
            // l'operazione di registrationplayer con un delay di 5 secondi
            MarketClosedException => println@Console( MARKET_CLOSED_EXCEPTION )();
                                        sleep@Time( 5000 )(); registration2player@Self()
        );

        /* Verifica lo stato del Market */
        checkMarketStatus@PlayerToMarketCommunication()( server_conn );

       /*
       * La prima cosa che un Player fa appena viene al mondo è registrarsi presso il
       * Market, il Market gli risponde con una struttura dati che riflette il suo
       * account, e che contiene quindi nome, stock posseduti e relative quantità,
       * denaro disponibile. Il player se la salva in 'status'.
       */
        registerPlayer@PlayerToMarketCommunication(Player_Name1)(newStatus1);
        global.status1 << newStatus1;
        registerPlayer@PlayerToMarketCommunication(Player_Name2)(newStatus2);
        global.status2 << newStatus2;

        // inizializza prezzi degli stock
        infoStockList;

        // start dei due player
        run2player@Self()
    }


    // OneWay riflessivo; operazione esecuzione dei due player
    [ run2player() ] {

        /*
         * Il player mantiene queste due piccole strutture dati alle quali cambia
         * di volta in volta il nome dello stock oggetto della transazione prima di
         * inviare la richiesta.
         */
        with( nextBuy1 ) {
            .player = Player_Name1;
            .stock = ""
        };
        with ( nextSell1 ) {
            .player = Player_Name1;
            .stock = ""
        };
        with( nextBuy2 ) {
            .player = Player_Name2;
            .stock = ""
        };
        with ( nextSell2 ) {
            .player = Player_Name2;
            .stock = ""
        };

        while ( true ) {

            {
                infoStockList;
                randGenStock;
                infoStockPrice@PlayerToMarketCommunication( stockName )( responsePrice );
                if (DEBUG) println@Console(" 1  prezzo di " + stockName + " = "  + responsePrice )();
                if (DEBUG) println@Console("qtà utente1 "+ global.status1.ownedStock.(stockName).quantity + " liq.utente1 "+ global.status1.liquidity )();

                // politica 1 -
                // Se il prezzo corrente è salito meno del 10% dall'ultima operazione allora compro
                // se il prezzo corrente è salito più del 30% o è sceso più del 5% dall'ultima operazione allora vendo
                if (global.status1.liquidity > responsePrice && global.stocks1.(stockName).price  <=  double(responsePrice * 1.10) ) {
                    infoStockAvailability@PlayerToMarketCommunication( stockName )( responseAvailability );
                    if (DEBUG) println@Console(" 1 disponibilità di " + stockName + " = " + responseAvailability )();

                    if (responseAvailability > 0 ) {
                        nextBuy1.stock = stockName; buy1;
                        global.stocks1.(stockName).price = responsePrice;
                        if (DEBUG) println@Console(" COMPRATO da utente1  a " + responsePrice)()
                    }

                } else if(global.status1.ownedStock.(stockName).quantity > 0 &&
                     (global.stocks1.(stockName).price <= double(responsePrice * 1.05) || (global.stocks1.(stockName).price > double(responsePrice * 1.30)) ) ){
                    nextSell1.stock = stockName; sell1;
                    if (DEBUG) println@Console(" VENDUTO da utente1 "+ global.status1.liquidity )();
                    global.stocks1.(stockName).price = responsePrice
                }
            }
            |
            {
                infoStockList;
                randGenStock;
                infoStockPrice@PlayerToMarketCommunication( stockName )( responsePrice );
                if (DEBUG) println@Console(" 2 prezzo di " + stockName + " = "  + responsePrice )();
                if (DEBUG) println@Console(" qtà utente2 " + global.status2.ownedStock.(stockName).quantity + " liq.utente2 " + global.status2.liquidity)();

                // politica 2 -
                // Se il prezzo corrente è salito meno del 5% dall'ultima operazione allora compro
                // se il prezzo corrente è salito più del 40% o è sceso più del 2% dall'ultima operazione allora vendo
                if (global.status2.liquidity > responsePrice && global.stocks2.(stockName).price  <=  double(responsePrice * 1.05) ) {
                    infoStockAvailability@PlayerToMarketCommunication( stockName )( responseAvailability );
                    if (DEBUG) println@Console(" 2 disponibilità di " + stockName + " = " + responseAvailability )();

                    if (responseAvailability > 0 ) {
                        nextBuy2.stock = stockName; buy2;
                        global.stocks2.(stockName).price = responsePrice;
                        if (DEBUG) println@Console(" COMPRATO da utente2 " + responsePrice)()
                    }

                } else if(global.status2.ownedStock.(stockName).quantity > 0 &&
                     (global.stocks2.(stockName).price <= double(responsePrice * 1.02) || (global.stocks2.(stockName).price > double(responsePrice * 1.40)) ) ){
                    nextSell2.stock = stockName; sell2;
                    if (DEBUG) println@Console(" VENDUTO da utente2 "+ global.status2.liquidity )();
                    global.stocks2.(stockName).price = responsePrice
                }
            };

            // ripete una nuova operazione su uno dei due player
            sleep@Time( Frequence )();

            /* Verifica lo stato del Market */
            checkMarketStatus@PlayerToMarketCommunication()( server_conn )
        }
    }
}
