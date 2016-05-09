include "../config/constants.iol"
include "file.iol"
include "../interfaces/stockInterface.iol"

include "console.iol"
include "string_utils.iol"
include "xml_utils.iol"

include "runtime.iol"
include "time.iol"


// embedded by StocksLauncher
inputPort StocksMng {
    Location: "local"
    Interfaces: StocksLauncherInterface
}

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



execution { concurrent }

main {

/*
sulle operazioni buyStock e sellStock sono ricevute chiamate "aggregate" per tutti gli stock client in esecuzione
StocksMng svolge le veci di 'proxy' tra il market e ciascun stock
(mentre per le chiamate in uscita, ciascun stock è assolutamente indipendente, ovvero dialoga con il market direttamente)
il motivo di tali scelte? Sostanzialmente l'assenza del dynamic binding sulle input port che, tradotto in altri termini,
non permette la definizione dinamica delle input port sulle singole istanze dei thread stock dinamicamente allocati
*/

/*
ricorda la composizione della struttura global.dynamicStockList (su cui è applicabile il dynamic lookup)
utilizzata da tutte le operazioni offerte da StocksMng.ol
dynamicStockList.( stockName )[ 0 ].fileName
dynamicStockList.( stockName )[ 0 ].location
*/
    [ buyStock( stockName )( response ) {

// dynamic lookup rispetto alla stringa stockName
        if ( is_defined( global.dynamicStockList.( stockName )[ 0 ] )) {
// per comunicare con la specifica istanza, imposto a runtime la location della outputPort StockInstance
            StockInstance.location = global.dynamicStockList.( stockName )[ 0 ].location;
// posso adesso avviare l'operazione sullo specifico stock
            buyStock@StockInstance()( response )
        } else {
             //Lo stock non esiste
            throw( StockUnknownException )
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
            //Lo stock non esiste
            throw( StockUnknownException )
        }

    } ] { nullProcess }


    /*
    * Operazione infoStockAvaliability dell'interfaccia
    * MarketToStockCommunicationInterface
    *
    * porta 8000 | Client: Market | Server: StocksMng
    */
    [ infoStockAvaliability( stockName )( responseAvaliability ) {
        if ( is_defined( global.dynamicStockList.( stockName )[ 0 ])) {
            StockInstance.location = global.dynamicStockList.( stockName )[ 0 ].location;
            infoStockAvaliability@StockInstance()( responseAvaliability )
        } else {
            // todo: meglio lanciare un fault...
            responseAvaliability = -1
        }
    } ] { nullProcess }



/*
operazione invocata da StocksLauncher (innesco)

estraggo ciascun file xml dal path indicato ed effettuo 2 verifiche: una sul filename, l'altra sul nome dello stock;
qualora il filename non sia già presente all'interno della lista degli stock correnti,
allora posso verificare il nome dello stock in esso contenuto;
qualora anche il nome non sia già presente, allora posso lanciare lo stock a runtime
*/
    [ discover( interval )() {

// todo: creare scope specifici ed effettuare install più dettagliati;
// todo: affiancare procedure define per snellire la lettura del codice
        install(
                    // stock list up to date
                    StocksDiscovererFault => println@Console( stocksDiscovery.StocksDiscovererFault.msg )(),

                    IOException => throw( IOException ),
                    FileNotFound => throw( FileNotFound ),

                    RuntimeExceptionType => throw( RuntimeExceptionType )
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

                if (DEBUG) println@Console( "StocksMng@discover: analizzo " + currentFile)();

// i filename presenti si riferiscono a stock già in esecuzione? Quindi già presenti nella struct dynamicStockList?
                found = false;
                foreach ( stockName : global.dynamicStockList ) {
                    if ( currentFile == global.dynamicStockList.( stockName )[ 0 ].filename ) {
                        found = true
                    }
                };

// qualora il filename in esame non abbia trovato alcuna corrispondenza, posso allora procedere alle ulteriori verifiche
                if ( found == false ) {

                    if (DEBUG) println@Console( "StocksMng@discover: il file corrente (" + currentFile + ") non è presente in dynamicStockList")();

// procedo con la lettura del file xml
                    filePath = CONFIG_PATH_STOCKS + currentFile;
                    exists@File( filePath )( fileExists );

                    if ( fileExists ) {

                        if (DEBUG) println@Console( "StocksMng@discover: avvio la lettura dell'xml da " + filePath )();

/*
todo: catch typeMismatch fault
l'operazione xmlToValue può lanciare un TypeMismatchfault qualora l'attributo _jolie_type non sia congruo con il valore
indicato; ricorda che non è incluso il nodo radice <stock>
*/
                        fileInfo.filename = filePath;
                        readFile@File( fileInfo )( xmlTree );
                        xmlTree.options.charset = "UTF-8";
                        xmlTree.options.schemaLanguage = "it";
                        xmlToValue@XmlUtils( xmlTree )( xmlStock );

// il nome dello stock è già presente nella lista? Verifico grazie ad un dynamic lookup
                        if ( ! is_defined( global.dynamicStockList.( xmlStock.name )[ 0 ] )) {

// abbiamo a che fare con un nuovo stock, dovremo quindi occuparci di lanciare una nuova istanza
// intanto compongo la struttura dati che la caratterizzerà
                            newStock.static << xmlStock;
                            newStock.static.filename = currentFile;
                            newStock.dynamic.availability = xmlStock.info.availability;
                            stockName -> newStock.static.name;

                            if (DEBUG) println@Console( "StocksMng@discover: trovato un nuovo stock " + stockName )();



                            if (DEBUG) println@Console( "StocksMng@discover: avvia una nuova istanza di stock (" +
                                                stockName + " / " + currentFile + ")" )();
// lancia una nuova istanza dello stock
                            embedInfo.type = "Jolie";
                            embedInfo.filepath = "Stock.ol";

// reminder: loadEmbeddedService returns the (local) location of the embedded service
                            loadEmbeddedService@Runtime( embedInfo )( StockInstance.location );

// qualora l'istruzione precedente non abbia generato alcun fault (RuntimeExceptionType)
// avvia la registrazione dello stock sul market

// TODO
// potrebbe essere una OneWay? Forse è più prundente attendere la risposta della procedura di registrazione sul market?
// l'operazione start avvia la procedura di registrazione dello stock sul market che tuttavia potrebbe essere chiuso
                            start@StockInstance( newStock )( response );

// aggiorno la dynamicStockList; il parametro location è di vitale importanza per la corretta identificazione delle istanze
                            global.dynamicStockList.( stockName)[ 0 ].filename = currentFile;
                            global.dynamicStockList.( stockName )[ 0 ].location = StockInstance.location

                        }
                    }
                }
            };

            sleep@Time( interval )()

        }
    } ] { nullProcess }
}
