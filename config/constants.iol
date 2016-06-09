constants {
// contiene i files di configurazione xml di ciascun stock
    CONFIG_PATH_STOCKS = "../config/stocks/",

// potrebbe essere utile qualora decidessimo di salvare la stato dei player a mercato chiuso
    CONFIG_PATH_PLAYERS = "../config/players/",

// path relativo utile per i servizi all'interno di main/
    EMBEDDED_SERVICE_PATH = "../embeddedService/",
    EMBEDDED_SERVICE_STOCK = "../embeddedService/Stock.ol",

// messaggi di diagnostica sullo stato dei servizi ed altre eccezioni
    MARKET_DOWN_EXCEPTION = "Caught IOException: Market is down",
    MARKET_CLOSED_EXCEPTION = "Caught MarketCloseException: Market is closed",
    STOCK_DUPLICATED_EXCEPTION = "Caught StockDuplicatedException:  the current stock is already registered",
    STOCK_UNKNOWN_EXCEPTION = "Caught StockUnknownException: the request involves an unknown stock",
    PLAYER_DUPLICATED_EXCEPTION = "Caught PlayerDuplicatedException: the current player is already registered",
    PLAYER_UNKNOWN_EXCEPTION = "Caught PlayerUnknownException: the request involves an unknown player",

// errore generico, cumulativo, per le eventuali eccezioni sollevate in discover@StocksMng
    STOCK_GENERIC_ERROR_MSG = "Impossible to launch the stock, it could trigger errors",
// dopo n tentativi, qualora il market sia ancora chiuso
    CONNECTION_ATTEMPTS_MSG = "Too many connection attempts. Market is still closed. Closing program. Bye ;)",

// numero massimo di tentativi di connessione al market; se oltrepassati il programma viene interrotto
    MAX_CONNECTION_ATTEMPTS = 5,

// liquidità iniziale di default del player
    DEFAULT_PLAYER_LIQUIDITY = 100,
// numero di decimali a cui arrotondare i vari importi
    DECIMAL_ROUNDING = 5,
// come da specifiche: il prezzo di uno Stock non può mai scendere sotto il valore di 10
    MINIMUN_STOCK_PRICE = 10,

// se true attiva stampe di controllo
    DEBUG = false
}