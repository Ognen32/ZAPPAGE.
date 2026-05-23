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

    // MARK: - Errors
    var errorEmailRequired: String    { l("Email is required.",                   "Е-маилот е задолжителен.") }
    var errorPasswordShort: String    { l("Password must be at least 6 characters.", "Лозинката мора да има најмалку 6 знаци.") }
    var errorUsernameRequired: String { l("Username is required.",                "Корисничкото име е задолжително.") }

    // MARK: - Helper
    private func l(_ en: String, _ mk: String) -> String {
        language == .macedonian ? mk : en
    }
}
