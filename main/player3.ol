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
    Player_Name = "Default Player"
}

execution { single }

//Il Player aggiorna il suo status (liquidità e stock posseduti) in funzione
//dell'esito delle sue operazioni

define infoStockList {
    infoStockList@PlayerToMarketCommunication( "info" )( responseInfo );
    println@Console( "informazioni ricevute sugli stock" )();
    for ( k = 0, k < #responseInfo.name, k++ ) {
        println@Console( responseInfo.name[k] )();
        stockName=responseInfo.name[k];
        if ( ! is_defined( StockAllowed.(stockName).price1 )){
          StockAllowed.(stockName).price1=10000;
          println@Console( StockAllowed.(stockName).price1 )()
        }
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
        println@Console("prezzo del: " + stockName + " = "  + responsePrice )();
        if (double(StockAllowed.(stockName).price1 >responsePrice) && status.liquidity>responsePrice){
        nextBuy.stock = stockName; buy;
        StockAllowed.(stockName).price1 =responsePrice;
        println@Console("COMPRATOOOOOO" + StockAllowed.(stockName).price1)()
        }else if(status.ownedStock.(stockName).quantity>0){
          nextSell.stock = stockName; sell;
          println@Console("VENDUTOOOOOOO")();
          StockAllowed.(stockName).price1 =responsePrice
        }else{
          println@Console("NADA")()
          };
              /*infoStockAvailability@PlayerToMarketCommunication( stockName )( responseAvailability );
        println@Console("disponibilità di: " + stockName + " = " + responseAvailability )();
        */
// BOOM BOOM BOOM every 3 seconds
        sleep@Time( 1000 )();

        /* Verifica lo stato del Market */
        checkMarketStatus@PlayerToMarketCommunication()( server_conn )
    }
}
