import Modals
import UIKit

public struct ModalsFactory {

    // MARK: Properties

    private let upsellStoryboard: UIStoryboard
    private let discourageStoryboard: UIStoryboard
    private let userAccountUpdateStoryboard: UIStoryboard

    public init(colors: ModalsColors) {
        upsellStoryboard = UIStoryboard(name: "UpsellViewController", bundle: Bundle.module)
        discourageStoryboard = UIStoryboard(name: "DiscourageSecureCoreViewController", bundle: Bundle.module)
        userAccountUpdateStoryboard = UIStoryboard(name: "UserAccountUpdateViewController", bundle: Bundle.module)
        Modals_iOS.colors = colors
    }

    public func upsellViewController(upsellType: UpsellType) -> UpsellViewController {
        let upsell = upsellStoryboard.instantiate(controllerType: UpsellViewController.self)
        upsell.upsellType = upsellType
        return upsell
    }

    public func discourageSecureCoreViewController(onDontShowAgain: ((Bool) -> Void)?, onActivate: (() -> Void)?, onCancel: (() -> Void)?, onLearnMore: (() -> Void)?) -> UIViewController {
        let discourageSecureCoreViewController = discourageStoryboard.instantiate(controllerType: DiscourageSecureCoreViewController.self)
        discourageSecureCoreViewController.onDontShowAgain = onDontShowAgain
        discourageSecureCoreViewController.onActivate = onActivate
        discourageSecureCoreViewController.onCancel = onCancel
        discourageSecureCoreViewController.onLearnMore = onLearnMore
        return discourageSecureCoreViewController
    }

    public func userAccountUpdateViewController(viewModel: UserAccountUpdateViewModel, onPrimaryButtonTap: (() -> Void)?) -> UIViewController {
        let userAccountUpdateViewController = userAccountUpdateStoryboard.instantiate(controllerType: UserAccountUpdateViewController.self)
        userAccountUpdateViewController.viewModel = viewModel
        userAccountUpdateViewController.onPrimaryButtonTap = onPrimaryButtonTap
        return userAccountUpdateViewController
    }
}

extension UIStoryboard {
    func instantiate<T: UIViewController>(controllerType: T.Type) -> T {
        let name = "\(controllerType)".replacingOccurrences(of: "ViewController", with: "")
        let viewController = instantiateViewController(withIdentifier: name) as! T
        return viewController
    }
}
