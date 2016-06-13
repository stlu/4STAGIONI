include "../config/constants.iol"
include "../interfaces/commonInterface.iol"
include "../interfaces/playerInterface.iol"

include "console.iol"
include "time.iol"
include "string_utils.iol"
include "math.iol"

outputPort PlayerToMarketCommunication {
    Location: "socket://localhost:8002"
    Protocol: sodep
    Interfaces: PlayerToMarketCommunicationInterface, MarketCommunicationInterface
}

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

execution { single }

//Il Player aggiorna il suo status (liquidità e stock posseduti) in funzione
//dell'esito delle sue operazioni

define infoStockList {
    infoStockList@PlayerToMarketCommunication( "info" )( responseInfo );
    if (DEBUG) print@Console( "info ricevute sugli stock: " )();
    for ( k = 0, k < #responseInfo.name, k++ ) {
        if (DEBUG) print@Console( responseInfo.name[k] )();
        stockName=responseInfo.name[k];
        if ( ! is_defined( StockAllowed.(stockName).price1 )) {
          infoStockPrice@PlayerToMarketCommunication( stockName )( responsePrice );
          StockAllowed.(stockName).price1=responsePrice;
          if (DEBUG) println@Console( StockAllowed.(stockName).price1 )()
        }
    }
}

// operazioni player1
define buy1 {
    buyStock@PlayerToMarketCommunication( nextBuy1 )( receipt );
    if(receipt.esito == true) {
        status1.ownedStock.(receipt.stock).quantity += receipt.kind;
        status1.liquidity += receipt.price
    }
}
define sell1 {
    sellStock@PlayerToMarketCommunication( nextSell1 )( receipt );
    if(receipt.esito == true) {
        status1.ownedStock.(receipt.stock).quantity += receipt.kind;
        status1.liquidity += receipt.price
    }
}
// operazioni player2
define buy2 {
    buyStock@PlayerToMarketCommunication( nextBuy2 )( receipt );
    if(receipt.esito == true) {
        status2.ownedStock.(receipt.stock).quantity += receipt.kind;
        status2.liquidity += receipt.price
    }
}
define sell2 {
    sellStock@PlayerToMarketCommunication( nextSell2 )( receipt );
    if(receipt.esito == true) {
        status2.ownedStock.(receipt.stock).quantity += receipt.kind;
        status2.liquidity += receipt.price
    }
}
define randGenStock {
// Returns a random number d such that 0.0 <= d < 1.0.
    random@Math()( rand );
    nStock=#responseInfo.name;
    n=100/nStock;
    rand=rand*100;
// genera un valore random, estremi inclusi
    if (rand<n){
      stockName=responseInfo.name[0]
    }else if (rand<2*n){
      stockName=responseInfo.name[1]
    }else{
      stockName=responseInfo.name[2]
    }
}


main {

// TODO:
// le eccezioni installate (e quindi catturate), qualora si presentino, di fatto interrompono l'esecuzione del main;
// è necessario pensare ad un qualche metodo di recovery per proseguire con le attività di acquisto | vendita
// pur segnalando e/o considerando le eccezioni catturate
    install(
// il player name è già in uso
            PlayerDuplicatedException =>        valueToPrettyString@StringUtils(  main.PlayerDuplicatedException )( result );
                                                println@Console( "PlayerDuplicatedException\n" + result )(),
// il player sta tentando di effettuare una transazione, ma non si è correttamente registrato presso il market
            PlayerUnknownException =>           valueToPrettyString@StringUtils(  main.PlayerUnknownException )( result );
                                                println@Console( "PlayerUnknownException\n" + result )(),
// lo stock ha terminato la sua disponibilità
            StockAvailabilityException =>       valueToPrettyString@StringUtils(  main.StockAvailabilityException )( result );
                                                println@Console( "StockAvailabilityException\n" + result )(),
// il player tenta di acquistare uno stock inesistente
            StockUnknownException =>            valueToPrettyString@StringUtils(  main.StockUnknownException )( result );
                                                println@Console( "StockUnknownException\n" + result )(),
// liquidità del player terminata
            InsufficientLiquidityException =>   valueToPrettyString@StringUtils(  main.InsufficientLiquidityException )( result );
                                                println@Console( "InsufficientLiquidityException\n" + result )(),
// il player non dispone dello stock che sta tentando di vendere
            NotOwnedStockException =>           valueToPrettyString@StringUtils(  main.NotOwnedStockException )( result );
                                                println@Console( "NotOwnedStockException\n" + result )()
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
    status1 << newStatus1;
    registerPlayer@PlayerToMarketCommunication(Player_Name2)(newStatus2);
    status2 << newStatus2;
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

    while ( server_conn ) {

        infoStockList;
        randGenStock;
        infoStockPrice@PlayerToMarketCommunication( stockName )( responsePrice );
        if (DEBUG) print@Console("\n prezzo di: " + stockName + " = "  + responsePrice )();
        infoStockAvailability@PlayerToMarketCommunication( stockName )( responseAvailability );
        if (DEBUG) println@Console(" disponibilità di: " + stockName + " = " + responseAvailability )();

        println@Console("qtà utente1 "+ status1.ownedStock.(stockName).quantity + " qtà utente2 " + status2.ownedStock.(stockName).quantity)();
        println@Console("liq.utente1 "+ status1.liquidity + " liq.utente2 " + status2.liquidity)();

        {
            // politica 1 -
            // Se il prezzo corrente è salito meno del 10% dall'ultima operazione allora compro
            // se il prezzo corrente è salito più del 30% o è sceso più del 5% dall'ultima operazione allora vendo
            if (status1.liquidity > responsePrice && StockAllowed.(stockName).price1  <=  double(responsePrice * 1.10) &&
                responseAvailability > 0 ) {
                nextBuy1.stock = stockName; buy1;
                StockAllowed.(stockName).price1 = responsePrice;
                if (DEBUG) println@Console(" COMPRATO da utente1  a " + responsePrice)()
            } else if(status1.ownedStock.(stockName).quantity > 0 &&
                 (StockAllowed.(stockName).price1 <= double(responsePrice * 1.05) || (StockAllowed.(stockName).price1 > double(responsePrice * 1.30)) ) ){
                nextSell1.stock = stockName; sell1;
                if (DEBUG) println@Console(" VENDUTO da utente1 "+ status1.liquidity )();
                StockAllowed.(stockName).price1 = responsePrice
            }
        }
        |
        {

            // politica 2 -
            // Se il prezzo corrente è salito meno del 5% dall'ultima operazione allora compro
            // se il prezzo corrente è salito più del 40% o è sceso più del 2% dall'ultima operazione allora vendo
            if (status2.liquidity > responsePrice && StockAllowed.(stockName).price1  <=  double(responsePrice * 1.05) &&
                responseAvailability > 0 ) {
                nextBuy2.stock = stockName; buy2;
                StockAllowed.(stockName).price1 = responsePrice;
                if (DEBUG) println@Console(" COMPRATO da utente2 " + responsePrice)()
            } else if(status2.ownedStock.(stockName).quantity > 0 &&
                 (StockAllowed.(stockName).price1 <= double(responsePrice * 1.05) || (StockAllowed.(stockName).price1 > double(responsePrice * 1.30)) ) ){
                nextSell2.stock = stockName; sell2;
                if (DEBUG) println@Console(" VENDUTO da utente2 "+ status2.liquidity )();
                StockAllowed.(stockName).price1 = responsePrice
            }
        }
        |


// BOOM BOOM BOOM every 3 seconds
        sleep@Time( Frequence )();

        /* Verifica lo stato del Market */
        checkMarketStatus@PlayerToMarketCommunication()( server_conn )
    }
}
