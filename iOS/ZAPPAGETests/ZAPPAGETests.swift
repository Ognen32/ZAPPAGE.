import Testing
@testable import ZAPPAGE

struct AuthViewModelTests {
    @Test func emptyEmailFails() {
        let vm = AuthViewModel()
        vm.email = ""
        vm.password = "secret123"
        vm.submitEmail()
        #expect(vm.errorMessage != nil)
    }

    @Test func shortPasswordFails() {
        let vm = AuthViewModel()
        vm.email = "user@zapcomics.app"
        vm.password = "abc"
        vm.submitEmail()
        #expect(vm.errorMessage != nil)
    }
}
