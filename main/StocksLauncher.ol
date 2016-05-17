include "../config/constants.iol"
include "file.iol"
include "../interfaces/commonInterface.iol"
include "../interfaces/stockInterface.iol"

include "console.iol"
include "string_utils.iol"



// StocksMng.ol espone una sola operazione al launcher, ovvero quella di discovering, dalla quale scaturisce la creazione
// dinamica delle varie stock instances
outputPort StocksMng { 
    Interfaces: StocksLauncherInterface
}

// embedding del servizio StocksMng (ovvero per accentratore / dispatcher per le varie istanze di stock)
embedded {
    Jolie:
        "../embeddedService/StocksMng.ol" in StocksMng
}



execution { single }

main {
    
    install(
//                default => nullProcess, // catch all exceptions
                
// la lista dei files di configurazione è aggiornata (up to date)
                StocksDiscovererFault => println@Console( main.StocksDiscovererFault.msg )(),

// TODO: intercettare i fault lanciati da discover@StocksMng
                IOException => throw( IOException ),
                FileNotFound => throw( FileNotFound )
            );

// effettua un check alla ricerca di nuovi stock ogni 30 secondi
    discoveringInterval = 5000;
    discover@StocksMng( discoveringInterval )( )
}