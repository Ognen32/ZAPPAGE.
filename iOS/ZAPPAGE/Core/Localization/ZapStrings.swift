import Foundation

enum ZapLanguage: String, CaseIterable {
    case english    = "EN"
    case macedonian = "МК"
}

struct ZapStrings {
    let language: ZapLanguage

    // MARK: - Auth
    var welcomeBack: String     { l("Welcome Back.",       "Добредојдовте.") }
    var welcomeAccent: String   { l("Back",                "Назад") }
    var welcomeMain: String     { l("Welcome ",            "Добредојдовте") }
    var joinThe: String         { l("Join the ",           "Придружи се на ") }
    var joinAccent: String      { l("Zap",                 "Зап") }

    var loginSubtitle: String   { l("Pick up where you left off and read your library on any device.",
                                    "Продолжете од каде сте застанале и читајте ја вашата библиотека на кој било уред.") }
    var signupSubtitle: String  { l("Thousands of comics. Zero excuses. Your library awaits.",
                                    "Илјадници стрипови. Ниту еден изговор. Твојата библиотека те чека.") }

    var logIn: String           { l("Log In",              "Најави се") }
    var signUp: String          { l("Sign Up",             "Регистрирај се") }
    var createAccount: String   { l("Create Account",      "Создај сметка") }

    var emailPlaceholder: String    { l("Email address",   "Е-маил адреса") }
    var passwordPlaceholder: String { l("Password",        "Лозинка") }
    var usernamePlaceholder: String { l("Username",        "Корисничко име") }
    var forgotPassword: String      { l("Forgot password?","Заборавена лозинка?") }

    var orContinueWith: String  { l("or continue with",   "или продолжи со") }
    var continueAsGuest: String { l("Continue as Guest ›","Продолжи како гостин ›") }

    var termsPrefix: String     { l("By continuing you agree to our ", "Со продолжувањето се согласувате со нашите ") }
    var terms: String           { l("Terms",               "Услови") }
    var termsAnd: String        { l(" and ",               " и ") }
    var privacyPolicy: String   { l("Privacy Policy",      "Политика за приватност") }
    var termsSuffix: String     { l(".",                   ".") }

    // MARK: - Sign-up
    var chooseYourHero: String { l("CHOOSE YOUR HERO", "ИЗБЕРИ ГО ТВОЈОТ ХЕРОЈ") }

    // MARK: - Home navigation
    var routeHome: String        { l("Home",              "Почетна") }
    var routeReading: String     { l("Currently Reading", "Моментално читам") }
    var routeLibrary: String     { l("My Library",        "Мојата библиотека") }
    var routeFavourites: String  { l("Favourites",        "Омилени") }
    var routeRead: String        { l("Read Comics",       "Прочитани стрипови") }

    // MARK: - Home sections
    var searchPlaceholder: String  { l("Search titles, characters, creators…", "Пребарај наслови, ликови, автори…") }
    var allPublishers: String      { l("All",                   "Сите") }
    var seeAll: String             { l("See all ›",             "Види ги сите ›") }
    var continueReading: String    { l("Continue Reading",      "Продолжи со читање") }
    var newThisWeek: String        { l("New This Week",         "Ново оваа недела") }
    var myLibrary: String          { l("My Library",            "Мојата библиотека") }
    var trending: String           { l("Trending",              "Во тренд") }
    var newBadge: String           { l("NEW",                   "НОВО") }
    var downloaded: String         { l("Downloaded",            "Преземено") }
    var nothingHere: String        { l("Nothing here yet.",     "Сè уште нема ништо.") }
    var pickUpWhere: String        { l("Pick Up Where You Left Off", "Продолжи од каде застана") }
    var resumeBtn: String          { l("Resume",                "Продолжи") }
    var issueWord: String          { l("Issue",                 "Број") }
    var pageWord: String           { l("Page",                  "Страна") }
    var ofWord: String             { l("of",                    "од") }

    // MARK: - Home subtitles
    var subtitleReading: String    { l("Pick up where you left off",   "Продолжи од каде застана") }
    var subtitleLibrary: String    { l("24 issues downloaded · 2.3 GB","24 броеви преземени · 2.3 GB") }
    var subtitleFavourites: String { l("Your saved comics & series",   "Твоите зачувани стрипови и серии") }
    var subtitleRead: String       { l("Finished issues · 142 total",  "Завршени броеви · 142 вкупно") }

    // MARK: - User menu
    var logOut: String             { l("Log Out",               "Одјави се") }

    // MARK: - Offline prompt
    var offlineTitle: String       { l("You're Offline",        "Сте офлајн") }
    var offlineSubtitle: String    { l("Connect to the ZAPPAGE server\nto browse and download comics.",
                                       "Поврзете се со ZAPPAGE серверот\nза да прелистувате и преземате стрипови.") }
    var connectNow: String         { l("Connect Now",           "Поврзи се") }
    var connectingLabel: String    { l("Connecting…",           "Поврзување…") }
    var orDivider: String          { l("or",                    "или") }
    var offlineFooter: String      { l("Continue reading your saved comics\nor import files from your device.",
                                       "Продолжете да читате зачувани стрипови\nили увезете датотеки од вашиот уред.") }
    var noResults: String          { l("No Results",               "Нема резултати") }
    var noResultsSub: String       { l("Try a different title, character, or creator.",
                                       "Обидете се со друг наслов, лик или автор.") }

    // MARK: - Errors
    var errorEmailRequired: String    { l("Email is required.",                   "Е-маилот е задолжителен.") }
    var errorPasswordShort: String    { l("Password must be at least 6 characters.", "Лозинката мора да има најмалку 6 знаци.") }
    var errorUsernameRequired: String { l("Username is required.",                "Корисничкото име е задолжително.") }

    // MARK: - Helper
    private func l(_ en: String, _ mk: String) -> String {
        language == .macedonian ? mk : en
    }
}
