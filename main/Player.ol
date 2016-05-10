include "../config/constants.iol"
include "../interfaces/playerInterface.iol"
include "../interfaces/marketInterface.iol"

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
    Player_Name = "Default Player"
}

execution { single }

// La sezione init deve essere prima di ogni define
init {
  install ( IOException => println@Console( "caught IOException :  Server is down" )() );
  install ( PlayerDuplicateException => println@Console( "caught PlayerDuplicateException : Player already exists" )() );
  install ( StockUnknownException => println@Console( "caught StockUnknownException : Stock not found" )() )
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
// genera un valore random, estremi inclusi
    if (rand<0.33){
      stockName="Oro"
    }else if(rand<0.66){
      stockName="Petrolio"
    }else{
      stockName="Grano"
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

        { nextBuy.stock = "Oro"; buy }
        |
        { nextSell.stock = "Oro"; sell }
        |
        { nextBuy.stock = "Grano"; buy }
        |
        { nextSell.stock = "Grano"; sell }
        |
        { nextBuy.stock = "Petrolio"; buy }
        |
        { nextSell.stock = "Petrolio"; sell }
        |
            //{ nextBuy.stock = "OroBIANCO"; buy }
            //|
            //{ nextSell.stock = "OroBIANCO"; sell }
            //|
        infoStockList;
        randGenStock;
        infoStockPrice@PlayerToMarketCommunication( stockName )( responsePrice );
        println@Console("prezzo del: " + stockName + " = "  + responsePrice )();
        infoStockAvailability@PlayerToMarketCommunication( stockName )( responseAvailability );
        println@Console("disponibilità di: " + stockName + " = " + responseAvailability )();


// BOOM BOOM BOOM every 3 seconds
        sleep@Time( 3000 )();

        /* Verifica lo stato del Market */
        checkMarketStatus@PlayerToMarketCommunication()( server_conn )
    }
}
