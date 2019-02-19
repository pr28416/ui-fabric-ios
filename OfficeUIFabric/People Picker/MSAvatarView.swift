//
//  Copyright © 2018 Microsoft Corporation. All rights reserved.
//

import UIKit

// MARK: MSAvatarSize

@objc public enum MSAvatarSize: Int, CaseIterable {
    case xSmall
    case small
    case medium
    case large
    case xLarge
    case xxLarge

    var font: UIFont {
        switch self {
        case .xSmall:
            return UIFont.systemFont(ofSize: 9)
        case .small:
            return UIFont.systemFont(ofSize: 12)
        case .medium:
            return UIFont.systemFont(ofSize: 13)
        case .large:
            return UIFont.systemFont(ofSize: 15)
        case .xLarge:
            return UIFont.systemFont(ofSize: 15)
        case .xxLarge:
            return UIFont.systemFont(ofSize: 28)
        }
    }

    var size: CGSize {
        switch self {
        case .xSmall:
            return CGSize(width: 18, height: 18)
        case .small:
            return CGSize(width: 25, height: 25)
        case .medium:
            return CGSize(width: 30, height: 30)
        case .large:
            return CGSize(width: 35, height: 35)
        case .xLarge:
            return CGSize(width: 40, height: 40)
        case .xxLarge:
            return CGSize(width: 70, height: 70)
        }
    }
}

// MARK: - MSAvatarStyle

@objc public enum MSAvatarStyle: Int {
    case circle
    case square
}

// MARK: - MSAvatarView

/**
 `MSAvatarView` is used to present an image or initials view representing an entity such as a person.
 If an image is provided the image is presented in either a circular or a square view based on the `MSAvatarStyle` provided with the initials view presented as a fallback.
 The initials used in the initials view are generated from the provided primary text (e.g. a name) or secondary text (e.g. an email address) used to initialize the avatar view.
 */
open class MSAvatarView: UIView {
    private struct Constants {
        static let borderWidth: CGFloat = 2
        static let xxLargeBorderWidth: CGFloat = 4
        static let animationDuration: TimeInterval = 0.2
        static let squareAvatarCornerRadius: CGFloat = 2
    }

    private struct SetupData: Equatable {
        let primaryText: String?
        let secondaryText: String?

        init(avatarView: MSAvatarView) {
            self.primaryText = avatarView.primaryText
            self.secondaryText = avatarView.secondaryText
        }
    }

    open var avatarSize: MSAvatarSize {
        didSet {
            frame.size = avatarSize.size
            initialsView.avatarSize = avatarSize
        }
    }
    open var avatarBackgroundColor: UIColor {
        didSet {
            initialsView.backgroundColor = avatarBackgroundColor
        }
    }

    private var primaryText: String?
    private var secondaryText: String?

    private var initialsView: MSInitialsView
    private let imageView: UIImageView
    // Use a view as a border to avoid leaking pixels on corner radius
    private let borderView: UIView

    private let style: MSAvatarStyle

    /// Initializes the avatar view with a size and an optional border
    ///
    /// - Parameters:
    ///   - avatarSize: The MSAvatarSize to configure the avatar view with
    ///   - hasBorder: Boolean describing whether or not to show a border around the avatarView
    ///   - style: The `MSAvatarStyle` to indicate whether the avatar should be displayed as a circle or a square
    @objc public init(avatarSize: MSAvatarSize, withBorder hasBorder: Bool = false, style: MSAvatarStyle = .circle) {
        self.avatarSize = avatarSize
        self.style = style
        avatarBackgroundColor = UIColor.clear

        initialsView = MSInitialsView(avatarSize: avatarSize)
        initialsView.isHidden = true

        imageView = UIImageView()
        imageView.isHidden = true
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill

        borderView = UIView(frame: .zero)
        borderView.backgroundColor = .white
        borderView.isHidden = !hasBorder

        super.init(frame: CGRect(origin: .zero, size: avatarSize.size))

        addSubview(borderView)
        addSubview(initialsView)
        addSubview(imageView)
    }

    @objc public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override var intrinsicContentSize: CGSize {
        return avatarSize.size
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        return avatarSize.size
    }

    open override func layoutSubviews() {
        super.layoutSubviews()

        imageView.frame = bounds
        initialsView.frame = imageView.frame

        imageView.layer.cornerRadius = style == .circle ? imageView.width / 2 : Constants.squareAvatarCornerRadius
        initialsView.layer.cornerRadius = imageView.layer.cornerRadius

        if !borderView.isHidden {
            let borderWidth = avatarSize == .xxLarge ? Constants.xxLargeBorderWidth : Constants.borderWidth
            borderView.frame = bounds.insetBy(dx: -borderWidth, dy: -borderWidth)
            borderView.layer.cornerRadius = imageView.layer.cornerRadius
        }
    }

    // MARK: Setup

    /// Sets up the avatarView to show an image or initials based on if an image is provided
    ///
    /// - Parameters:
    ///   - primaryText: The primary text to create initials with (e.g. a name)
    ///   - secondaryText: The secondary text to create initials with if primary text is not provided (e.g. an email address)
    ///   - image: The image to be displayed
    public func setup(primaryText: String?, secondaryText: String?, image: UIImage?) {
        self.primaryText = primaryText
        self.secondaryText = secondaryText

        if let image = image {
            setupWithImage(image)
        } else {
            setupWithInitials()
        }

        accessibilityLabel = primaryText ?? secondaryText
    }

    /// Sets up the avatarView with an image
    ///
    /// - Parameters:
    ///   - image: The image to be displayed
    public func setup(image: UIImage) {
        primaryText = nil
        secondaryText = nil

        setupWithImage(image)
    }

    private func setupWithInitials() {
        initialsView.setup(primaryText: primaryText, secondaryText: secondaryText)
        initialsView.isHidden = false
        imageView.isHidden = true
        if let initialsViewBackgroundColor = initialsView.backgroundColor {
            avatarBackgroundColor = initialsViewBackgroundColor
        }
    }

    private func setupWithImage(_ image: UIImage, animated: Bool = false) {
        let setupImageViewBlock: () -> Void = {
            self.imageView.image = image
            self.initialsView.isHidden = true
            self.imageView.isHidden = false
        }

        // Avoid to dispatch to next runloop, this leads to blinks if we need to reload an avatar view.
        if Thread.isMainThread {
            setupImageViewBlock()
        } else {
            let setupData = SetupData(avatarView: self)
            DispatchQueue.main.async { [weak self] in
                guard let this = self else {
                    return
                }

                // Avatar view was concurrently setup with different values
                if setupData != SetupData(avatarView: this) {
                    return
                }

                if animated {
                    UIView.transition(with: this, duration: Constants.animationDuration, options: [.transitionCrossDissolve], animations: setupImageViewBlock)
                } else {
                    setupImageViewBlock()
                }
            }
        }
    }

    // MARK: Accessibility

    open override var isAccessibilityElement: Bool { get { return true } set { } }
    open override var accessibilityLabel: String? { get { return primaryText ?? secondaryText } set { } }
    open override var accessibilityTraits: UIAccessibilityTraits { get { return .image } set { } }
}