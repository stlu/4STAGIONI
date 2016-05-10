constants {
// contiene i files di configurazione xml di ciascun stock
    CONFIG_PATH_STOCKS = "../config/stocks/",

// potrebbe essere utile qualora decidessimo di salvare la stato dei player a mercato chiuso
    CONFIG_PATH_PLAYERS = "../config/players/",

// messaggi di diagnostica sullo stato del market ed altre eccezioni
    MARKET_DOWN_EXCEPTION = "caught IOException : Market is down",
    MARKET_CLOSED_EXCEPTION = "caught MarketCloseException : Market is closed",
    STOCK_DUPLICATED_EXCEPTION = "caught StockDuplicatedException : the current stock is already registered",

// se true attiva stampe di controllo
    DEBUG = false
}