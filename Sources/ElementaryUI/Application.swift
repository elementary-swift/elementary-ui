/// A type that represents the main entry point of an ElementaryUI application.
///
/// `Application` establishes the origin point of your view tree and manages the lifecycle of
/// your entire application.
///
/// ## Creating an Application
///
/// Create an application by passing your root view to the initializer:
///
/// ```swift
/// let app = Application(MyRootView())
/// ```
///
/// ## Running the Application
///
/// Start your application by mounting it into a target element:
///
/// ```swift
/// app.mount(in: .body)  // Use document body as container
/// app.mount(in: "#app") // Use element with id="app"
/// ```
public struct Application<ContentView: View>: ~Copyable {
    let contentView: ContentView

    /// Creates a new application that will own and manage the specified root view.
    ///
    /// - Parameter contentView: The view that represents the top of your view hierarchy.
    public init(_ contentView: consuming ContentView) {
        self.contentView = contentView
    }
}

/// A handle to a running ElementaryUI application.
///
/// This type is returned when you successfully start an ``Application``. It represents
/// the active view hierarchy and provides control over the running application instance.
///
/// ## Usage
///
/// ```swift
/// let app = Application(MyView())
/// if let mounted = app.mount(in: .body) {
///     // Application is now running and managing your view hierarchy
///     // Future: mounted.unmount() to clean up
/// }
/// ```
public struct MountedApplication: ~Copyable {
    private var _unmount: () -> Void

    init(unmount: @escaping () -> Void) {
        self._unmount = unmount
    }

    /// Removes the application from the DOM and cleans up all resources.
    public consuming func unmount() {
        _unmount()
    }
}

extension Application {
    /// Starts the application and establishes your view hierarchy within the specified container.
    ///
    /// This method initializes the ElementaryUI runtime, establishes the root of your view tree,
    /// and sets up the reactive rendering system..
    ///
    /// ## Examples
    ///
    /// Start using the document body as the container:
    /// ```swift
    /// let app = Application(MyView())
    /// app.mount(in: .body)
    /// ```
    ///
    /// Start using a specific container element:
    /// ```swift
    /// let app = Application(MyView())
    /// app.mount(in: "#app")
    /// ```
    ///
    /// Handle failures gracefully:
    /// ```swift
    /// let app = Application(MyView())
    /// if let mounted = app.mount(in: "#app") {
    ///     print("Application is running")
    /// } else {
    ///     print("Failed to find container element")
    /// }
    /// ```
    ///
    /// - Parameter element: A ``DOMElementSelector`` specifying the container for your view hierarchy.
    ///   Use `.body` for the document body, or a CSS selector string like `"#app"` or `".container"`.
    ///
    /// - Returns: A ``MountedApplication`` handle if successful, or `nil` if the container
    ///   element cannot be found.
    @discardableResult
    public consuming func mount(in element: DOMElementSelector) -> MountedApplication? {
        guard let domNode = element.findDOMNode(dom: JSKitDOMInteractor.shared) else {
            logError("Mounting application failed: no DOM node found for \(element)")
            return nil
        }

        let runtime = ApplicationRuntime(dom: JSKitDOMInteractor.shared, domRoot: domNode, appView: contentView)
        return MountedApplication(unmount: runtime.unmount)
    }
}
