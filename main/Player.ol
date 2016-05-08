include "../config/constants.iol"
include "../interfaces/playerInterface.iol"

include "console.iol"
include "time.iol"
include "string_utils.iol"


outputPort PlayerToMarketCommunication {
    Location: "socket://localhost:8002"
    Protocol: sodep
    Interfaces: PlayerToMarketCommunicationInterface
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

main {
/*
 * La prima cosa che un Player fa appena viene al mondo è registrarsi presso il
 * Market, il Market gli risponde con una struttura dati che riflette il suo
 * account, e che contiene quindi nome, stock posseduti e relative quantità,
 * denaro disponibile. Il player se la salva in 'status'.
 */
    registerPlayer@PlayerToMarketCommunication(Player_Name)(newStatus);
    status << newStatus;

    while ( true ) {
        buyStock@PlayerToMarketCommunication( "Oro" )( response ) |
        sellStock@PlayerToMarketCommunication( "Oro" )( response ) |
        buyStock@PlayerToMarketCommunication( "Petrolio" )( response ) |
        sellStock@PlayerToMarketCommunication( "Petrolio" )( response ) |
        buyStock@PlayerToMarketCommunication( "Grano" )( response ) |
        sellStock@PlayerToMarketCommunication( "Grano" )( response )|
        infoStockList@PlayerToMarketCommunication( "info" )( responseInfo );
        println@Console( "informazioni ricevute sugli stock" )();
        for ( k = 0, k < #responseInfo.name, k++ ) {
          println@Console( responseInfo.name[k] )()
        };
        infoStockPrice@PlayerToMarketCommunication( "Petrolio" )( responsePrice );
        println@Console("prezzo stock: "  + responsePrice )();
        infoStockAvaliability@PlayerToMarketCommunication( "Petrolio" )( responseAvaliability );
        println@Console("disponibilità stock: "  + responseAvaliability )();


// BOOM BOOM BOOM every 3 seconds
        sleep@Time( 3000 )()
    }
}
