include "../config/constants.iol"
include "../interfaces/commonInterface.iol"
include "../interfaces/playerInterface.iol"

include "console.iol"
include "time.iol"
include "runtime.iol"
include "string_utils.iol"
include "math.iol"

outputPort PlayerToMarketCommunication {
    Location: "socket://localhost:8002"
    Protocol: sodep
    Interfaces: PlayerToMarketCommunicationInterface, MarketCommunicationInterface
}


// definizioni di interfaccia e outputPort per un'invocazione "riflessiva"
interface LocalInterface {
    OneWay: registrationplayer( void ) // registrazione del player presso il market
    OneWay: runplayer( void )
}
inputPort LocalInputPort {
    Location: "local"
    Interfaces: LocalInterface
}
outputPort Self { Interfaces: LocalInterface }
/*
 * Il valore della costante viene sovrascritto lanciando Player.ol con:
 *
     *  jolie -C Player_Name=\"Johnny\" Player.ol
 */
constants {
    Player_Name = "Random Player",
    Frequence = 3000
}

execution { single }

// La sezione init deve essere prima di ogni define
init {
    // Imposta la location della output port Self per comunicare con le operazioni esposte in LocalInterface
    getLocalLocation@Runtime()( Self.location );
    registrationplayer@Self();    // registra player

    install (
        //  market è down errore irreversibile,interrompo l'esecuzione del programma
            IOException =>                      println@Console( MARKET_DOWN_EXCEPTION )();
                                                valueToPrettyString@StringUtils( global.status )( result );
                                                println@Console( "Random Player " + result )();halt@Runtime()(),

        // il player name è già in uso interrompe esecuzione
            PlayerDuplicatedException =>        valueToPrettyString@StringUtils(  main.PlayerDuplicatedException )( result );
                                                println@Console( "PlayerDuplicatedException\n" + result )(); halt@Runtime()(),

        // il player sta tentando di effettuare una transazione, ma non si è correttamente registrato presso il market
            PlayerUnknownException =>           valueToPrettyString@StringUtils(  main.PlayerUnknownException )( result );
                                                println@Console( "PlayerUnknownException\n" + result )();
                                                runplayer@Self(),
        // lo stock ha terminato la sua disponibilità
            StockAvailabilityException =>       valueToPrettyString@StringUtils(  main.StockAvailabilityException )( result );
                                                println@Console( "StockAvailabilityException\n" + result )();
                                                runplayer@Self(),
        // il player tenta di acquistare uno stock inesistente
            StockUnknownException =>            valueToPrettyString@StringUtils(  main.StockUnknownException )( result );
                                                println@Console( "StockUnknownException\n" + result )();
                                                runplayer@Self(),
        // liquidità del player terminata
            InsufficientLiquidityException =>   valueToPrettyString@StringUtils(  main.InsufficientLiquidityException )( result );
                                                println@Console( "InsufficientLiquidityException\n" + result )();
                                                runplayer@Self(),
        // il player non dispone dello stock che sta tentando di vendere
            NotOwnedStockException =>           valueToPrettyString@StringUtils(  main.NotOwnedStockException )( result );
                                                println@Console( "NotOwnedStockException\n" + result )();
                                                runplayer@Self()
    )
}

execution { concurrent }
/****/

//Il Player aggiorna il suo status (liquidità e stock posseduti) in funzione
//dell'esito delle sue operazioni

define infoStockList {
    infoStockList@PlayerToMarketCommunication( "info" )( responseInfo );
    if (DEBUG) {
      println@Console( "informazioni ricevute sugli stock " )();
      for ( k = 0, k < #responseInfo.name, k++ ) {
          println@Console( responseInfo.name[k] )()
      }
    }
}
define buy {
    buyStock@PlayerToMarketCommunication( nextBuy )( receipt );
    if(receipt.esito == true) {
        global.status.ownedStock.(receipt.stock).quantity += receipt.kind;
        global.status.liquidity += receipt.price
    }
}
define sell {
    sellStock@PlayerToMarketCommunication( nextSell )( receipt );
    if(receipt.esito == true) {
        global.status.ownedStock.(receipt.stock).quantity += receipt.kind;
        global.status.liquidity += receipt.price
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

  // registrazione del player sul market; intercetta eccezioni e gestisce i tentativi di connessione
  [ registrationplayer() ] {

      install(
          // se il player tenta la registrazione ed il market è down errore irreversibile,
          // interrompo l'esecuzione del programma
          IOException => println@Console( MARKET_DOWN_EXCEPTION )(); halt@Runtime()(),

          // se il player tenta la registrazione ed il market è chiuso, riesegue ciclicamente
          // l'operazione di registrationplayer con un delay di 5 secondi
          MarketClosedException => println@Console( MARKET_CLOSED_EXCEPTION )();
                                      sleep@Time( 5000 )(); registrationplayer@Self()
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
      global.status << newStatus;

      // start player
      runplayer@Self()
  }

  // OneWay riflessivo; operazione esecuzione del player
  [ runplayer() ] {

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

    while ( true ) {
        infoStockList;
        randGenStock;
        infoStockPrice@PlayerToMarketCommunication( stockName )( responsePrice );
        infoStockAvailability@PlayerToMarketCommunication( stockName )( responseAvailability );
        randGenAction;
        if (action==1){
          nextBuy.stock = stockName; buy;
          if (DEBUG) println@Console("comprato "+ stockName)()
        }else if(action==2 && global.status.ownedStock.(stockName).quantity>0){
          nextSell.stock = stockName; sell;
          if (DEBUG) println@Console("venduto"+ stockName)()
        };

// BOOM BOOM BOOM every 3 seconds
          sleep@Time( Frequence )();

        /* Verifica lo stato del Market */
        checkMarketStatus@PlayerToMarketCommunication()( server_conn )
    }
  }
}
