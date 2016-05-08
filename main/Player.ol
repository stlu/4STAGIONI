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


execution { single }

init {
  install ( IOException => println@Console( "caught IOException :  Server is down" )() );
  install ( PlayerDuplicateException => println@Console( "caught PlayerDuplicateException : Player already exists" )() );
  install ( StockUnknownException => println@Console( "caught StockUnknownException : Stock not found" )() )
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

    while ( server_conn ) {
        buyStock@PlayerToMarketCommunication( "Oro" )( response ) |
        sellStock@PlayerToMarketCommunication( "Oro" )( response ) |
        buyStock@PlayerToMarketCommunication( "Petrolio" )( response ) |
        sellStock@PlayerToMarketCommunication( "Petrolio" )( response ) |
        buyStock@PlayerToMarketCommunication( "Grano" )( response ) |
        sellStock@PlayerToMarketCommunication( "Grano" )( response )|
                //buyStock@PlayerToMarketCommunication( "OroBIANCO" )( response ) |
                //sellStock@PlayerToMarketCommunication( "OroBIANCO" )( response ) |
        infoStockList@PlayerToMarketCommunication( "info" )( responseInfo );
        println@Console( "informazioni ricevute sugli stock" )();
        for ( k = 0, k < #responseInfo.name, k++ ) {
          println@Console( responseInfo.name[k] )()
        };
        randGenStock;
        infoStockPrice@PlayerToMarketCommunication( stockName )( responsePrice );
        println@Console("prezzo del: " + stockName + " = "  + responsePrice )();
        infoStockAvaliability@PlayerToMarketCommunication( stockName )( responseAvaliability );
        println@Console("disponibilità di: " + stockName + " = " + responseAvaliability )();


// BOOM BOOM BOOM every 3 seconds
        sleep@Time( 3000 )();

        /* Verifica lo stato del Market */
        checkMarketStatus@PlayerToMarketCommunication()( server_conn )
    }
}
