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
     *  jolie -C Player_Name=\"Johnny\" Player.ol
 */
constants {
    Player_Name = "Random Player"
}

execution { single }

// La sezione init deve essere prima di ogni define
init {
// così come suggerito da Stefania, dichiaramo tutte le eccezioni nell'init
// (una dichiarazione cumulativa per tutti i throw invocati in ciascuna operazione);
// qualora sia invece necessario intraprendere comportamenti specifici è bene definire l'install all'interno dello scope
    scope( commonFaultScope ) {
        install(
                IOException => println@Console( MARKET_DOWN_EXCEPTION )(),
                PlayerDuplicatedException => println@Console( PLAYER_DUPLICATED_EXCEPTION +
                                              " (" + commonFaultScope.PlayerDuplicatedException.playerName + ")")(),
                StockUnknownException => println@Console( PLAYER_DUPLICATED_EXCEPTION +
                                              " (" + commonFaultScope.StockUnknownException.stockName + ")")()
              )
    }
}

//Il Player aggiorna il suo status (liquidità e stock posseduti) in funzione
//dell'esito delle sue operazioni

define infoStockList {
    infoStockList@PlayerToMarketCommunication( "info" )( responseInfo );
    println@Console( "informazioni ricevute sugli stock" )();
    for ( k = 0, k < #responseInfo.name, k++ ) {
        println@Console( responseInfo.name[k] )()
    }
}
define buy {
    buyStock@PlayerToMarketCommunication( nextBuy )( receipt );
    if(receipt.esito == true) {
        status.ownedStock.(receipt.stock).quantity += receipt.kind;
        status.liquidity += receipt.price
    }
}
define sell {
    sellStock@PlayerToMarketCommunication( nextSell )( receipt );
    if(receipt.esito == true) {
        status.ownedStock.(receipt.stock).quantity += receipt.kind;
        status.liquidity += receipt.price
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

define randGenAction {
// Returns a random number d such that 0.0 <= d < 1.0.
    random@Math()( rand );
// genera un valore random, estremi inclusi
    if (rand<0.5){
        action=1
    }else {
      action=2
    }
}


main {

/* Verifica lo stato del Market */
   checkMarketStatus@PlayerToMarketCommunication()( server_conn );

   /*
   * La prima cosa che un Player fa appena viene al mondo è registrarsi presso il
   * Market, il Market gli risponde con una struttura dati che riflette il suo
   * account, e che contiene quindi nome, stock posseduti e relative quantità,
   * denaro disponibile. Il player se la salva in 'status'.
   */
    registerPlayer@PlayerToMarketCommunication(Player_Name)(newStatus);
    status << newStatus;
    /*
     * Il player mantiene queste due piccole strutture dati alle quali cambia
     * di volta in volta il nome dello stock oggetto della transazione prima di
     * inviare la richiesta.
     */
    with( nextBuy ) {
        .player = Player_Name;
        .stock = ""
    };
    with ( nextSell ) {
        .player = Player_Name;
        .stock = ""
    };

    while ( server_conn ) {
        infoStockList;
        randGenStock;
        infoStockPrice@PlayerToMarketCommunication( stockName )( responsePrice );
        infoStockAvailability@PlayerToMarketCommunication( stockName )( responseAvailability );
        randGenAction;
        if (action==1 && status.liquidity>responsePrice){
          nextBuy.stock = stockName; buy;
          println@Console("comprato "+ stockName)()
        }else if(action==2 && status.ownedStock.(stockName).quantity>0){
          nextSell.stock = stockName; sell;
          println@Console("venduto"+ stockName)()
        };

// BOOM BOOM BOOM every 3 seconds
          sleep@Time( 1000 )();

        /* Verifica lo stato del Market */
        checkMarketStatus@PlayerToMarketCommunication()( server_conn )
    }
}
