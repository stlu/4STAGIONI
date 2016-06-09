include "../config/constants.iol"
include "file.iol"
include "../interfaces/commonInterface.iol"
include "../interfaces/stockInterface.iol"

include "console.iol"
include "string_utils.iol"
include "xml_utils.iol"

include "runtime.iol"
include "time.iol"



// comunica con ciascun stock client dinamicamente allocato
// embeds n stock instances
outputPort StockInstance {
    Interfaces: StockInstanceInterface
}

// raccoglie le informazioni provenienti dal mercato rispetto alle operazioni di buy e sell e le inoltra alla specifica
// istanza di stock
inputPort MarketToStockCommunication {
    Location: "socket://localhost:8000"
    Protocol: sodep
    Interfaces: MarketToStockCommunicationInterface
}

// le seguenti definizioni di interfaccia e outputPort consento un'invocazione "riflessiva"
interface LocalInterface {
    OneWay: discover( int )
}
inputPort LocalInputPort { Location: "local" Interfaces: LocalInterface }
outputPort Self { Interfaces: LocalInterface }



define trigger { // innesco
    discoveringInterval = 5000;
    discover@Self( discoveringInterval )
}

// si è verificato un errore nell'operazione discover
define discoverFaultMng {
    println@Console( STOCK_GENERIC_ERROR_MSG + " (" + global.currentFile + ")" )();
// aggiungo il file di configurazione all'interno dell'exception list, così da prevenire il lancio
// di nuove eccezioni; successivamente innesco (di nuovo) l'operazione discover
    if ( ! is_defined( global.exceptionFileList.( currentFile )))
        global.exceptionFileList.( currentFile )[ 0 ] = true;

    trigger
}

init {
// who I am? Imposto la location della output port Self per comunicare con "me stesso", ovvero con le operazioni esposte
// in LocalInterface
    getLocalLocation@Runtime()( Self.location );
    trigger;

// così come suggerito da Stefania, dichiaramo tutte le eccezioni nell'init
// (una dichiarazione cumulativa per tutti i throw invocati in ciascuna operazione);
// qualora sia invece necessario intraprendere comportamenti specifici è bene definire l'install all'interno dello scope
// (nel nostro caso nell'operazione discover è previsto uno specifico install)
    install(
                StockUnknownException => throw( StockUnknownException )
            )
}



execution { concurrent }

main {

/*
sulle operazioni buyStock e sellStock sono ricevute chiamate "aggregate" per tutti gli stock client in esecuzione
StocksMng svolge le veci di proxy | dispatcher tra il market e ciascun stock
(mentre per le chiamate in uscita, ciascun stock è assolutamente indipendente, ovvero dialoga con il market direttamente)
il motivo di tali scelte? Sostanzialmente l'assenza del dynamic binding sulle input port che, tradotto in altri termini,
non permette la definizione dinamica delle input port sulle singole istanze dei thread stock dinamicamente allocati;
avremmo potuto alternativamente creare un launch script per ciascun stock, definendo la propria input port con una
costante
*/

/*
ricorda la composizione della struttura global.dynamicStockList (su cui è applicabile il dynamic lookup)
utilizzata da tutte le operazioni offerte da StocksMng.ol
dynamicStockList.( stockName )[ 0 ].fileName
dynamicStockList.( stockName )[ 0 ].location
*/
    [ buyStock( stockName )( response ) {

        install(
// eccezione rilanciabile dall'operazione buyStock            
            StockAvailabilityException => throw( StockAvailabilityException )
        );

// dynamic lookup rispetto alla stringa stockName
        if ( is_defined( global.dynamicStockList.( stockName )[ 0 ] )) {
// per comunicare con la specifica istanza, imposto a runtime la location della outputPort StockInstance
            StockInstance.location = global.dynamicStockList.( stockName )[ 0 ].location;
// posso adesso avviare l'operazione sullo specifico stock: verrà eseguito il forward della response ricevuta
            buyStock@StockInstance()( response )
        } else {
// lo stock richiesto non esiste, lancia un fault all'invocante (buyStock@Market)
            throw( StockUnknownException, { .stockName = stockName } )
        }

    } ] { nullProcess }



    [ sellStock( stockName )( response ) {

// dynamic lookup rispetto alla stringa stockName
        if ( is_defined( global.dynamicStockList.( stockName )[ 0 ] )) {
// per comunicare con la specifica istanza, imposto a runtime la location della outputPort StockInstance
            StockInstance.location = global.dynamicStockList.( stockName )[ 0 ].location;
// posso adesso avviare l'operazione sullo specifico stock
            sellStock@StockInstance()( response )
        } else {
// lo stock richiesto non esiste, lancia un fault all'invocante (sellStock@Market)
            throw( StockUnknownException, { .stockName = stockName } )
        }

    } ] { nullProcess }



/*
* Operazione infoStockAvaliability dell'interfaccia
* MarketToStockCommunicationInterface
*
* porta 8000 | Client: Market | Server: StocksMng
*/
    [ infoStockAvailability( stockName )( response ) {
        if ( is_defined( global.dynamicStockList.( stockName )[ 0 ])) {
            StockInstance.location = global.dynamicStockList.( stockName )[ 0 ].location;
            infoStockAvailability@StockInstance()( response )
        } else {
// lo stock richiesto non esiste, lancia un fault all'invocante (infoStockAvailability@Market)
            throw( StockUnknownException, { .stockName = stockName } )
        }

    } ] { nullProcess }



/*
estraggo ciascun file xml dal path indicato ed effettuo 2 verifiche: una sul filename, l'altra sul nome dello stock;
qualora il filename non sia già presente all'interno della lista degli stock correnti,
allora posso verificare il nome dello stock in esso contenuto;
qualora anche il nome non sia già presente, allora posso lanciare lo stock a runtime
*/
    [ discover( interval ) ] {
        scope( discoverScope ) {

            install(
                        default =>      global.exceptionFileList.( currentFile ) = currentFile;
                                        global.currentFile = currentFile;
                                        discoverFaultMng

/*
la specifica "default" cattura e gestisce tutte le seguenti casistiche:
IOException e FileNotFound possono verificarsi in fase di lettura da file;
RuntimeException può essere innescata da loadEmbeddedService@Runtime;
xmlToValue può lanciare un NumberFormatException fault qualora l'attributo _jolie_type
non sia congruo con il valore indicato;

StockDuplicatedException:
uno stock con lo stesso nome è già registrato sul market; caso poco probabile (se non impossibile) dato che è
effettuato un attento controllo sui nomi; il fault è tuttavia correttamente gestito all'interno di Stock.ol
*/
                    );

            while ( true ) {

// estraggo i files di configurazione degli stock dal basepath definito in ../config/constants.iol
                listRequest.directory = CONFIG_PATH_STOCKS;
                listRequest.regex = ".+\\.xml";
                listRequest.order.byname = true;
                list@File( listRequest )( listResult );

// ciclo su ciascun file all'interno della directory (qualora ve ne siano)
                for ( k = 0, k < #listResult.result, k++ ) {
                    currentFile = listResult.result[ k ];

                    if ( DEBUG )
                        println@Console( "StocksMng@discover: analizzo " + currentFile )();

// uno o più file di configurazione possono aver generato eccezioni
// (in fase di parsing o di lancio del relativo servizio embeddato)
                    if ( ! is_defined( global.exceptionFileList.( currentFile ))) {

// i filename presenti si riferiscono a stock già in esecuzione? Quindi già presenti nella struct dynamicStockList?
                        found = false;
                        foreach ( stockName : global.dynamicStockList ) {
                            if ( currentFile == global.dynamicStockList.( stockName )[ 0 ].filename )
                                found = true
                        };

                        if ( found == true ) {
                            if ( DEBUG )
                                println@Console( "StocksMng@discover: il file corrente (" + currentFile + ") è " +
                                                    "già presente in dynamicStockList")()

// qualora il filename in esame non abbia trovato alcuna corrispondenza, posso allora procedere con ulteriori verifiche                                            
                        } else {
                            if ( DEBUG )
                                    println@Console( "StocksMng@discover: il file corrente (" + currentFile + ") non è presente in dynamicStockList")();

// procedo con la lettura del file xml
                            filePath = CONFIG_PATH_STOCKS + currentFile;
                            exists@File( filePath )( fileExists );

                            if ( fileExists ) {

                                if ( DEBUG )
                                    println@Console( "StocksMng@discover: avvio la lettura dell'xml da " + filePath )();

// può lanciare un FileNotFound exception
                                fileInfo.filename = filePath;
                                readFile@File( fileInfo )( xmlTree );
                                xmlTree.options.charset = "UTF-8";
                                xmlTree.options.schemaLanguage = "it";
// Transforms the base value in XML format (data types string, raw) into a Jolie value.
// The XML root node will be discarded, the rest gets converted recursively                        
                                xmlToValue@XmlUtils( xmlTree )( xmlStock );

// il nome dello stock è già presente nella lista? Verifico grazie ad un dynamic lookup
                                if ( ! is_defined( global.dynamicStockList.( xmlStock.name )[ 0 ] )) {

// abbiamo a che fare con un nuovo stock, dovremo quindi occuparci di lanciare una nuova istanza
// intanto compongo la struttura dati che la caratterizzerà
                                    newStock.static << xmlStock;
                                    newStock.static.filename = currentFile;
                                    newStock.dynamic.availability = xmlStock.info.availability;
                                    stockName -> newStock.static.name;

                                    if ( DEBUG ) {
                                        println@Console( "StocksMng@discover: trovato un nuovo stock " + stockName )();
                                        println@Console( "StocksMng@discover: avvia una nuova istanza di stock (" +
                                                           stockName + " / " + currentFile + ")" )()
                                    };

// lancia una nuova istanza dello stock
                                    embedInfo.type = "Jolie";
                                    embedInfo.filepath = EMBEDDED_SERVICE_STOCK;

// reminder: loadEmbeddedService returns the (local) location of the embedded service
// può lanciare un RuntimeException
                                    loadEmbeddedService@Runtime( embedInfo )( StockInstance.location );

// qualora l'istruzione precedente non abbia generato alcun fault (RuntimeExceptionType)
// avvia la registrazione dello stock sul market

// non mi aspetto alcuna risposta; eventuali fault sono gestiti all'interno delle operazioni start e register
                                    start@StockInstance( newStock )();

// aggiorno la dynamicStockList; il parametro location è di vitale importanza per la corretta identificazione delle istanze
                                    global.dynamicStockList.( stockName )[ 0 ].filename = currentFile;
                                    global.dynamicStockList.( stockName )[ 0 ].location = StockInstance.location
                                }
                            }
                        }
                    }
                };

                sleep@Time( interval )()
            }
        }
    }
}