
/**
 * This file is part of the Phalcon Framework.
 *
 * (c) Phalcon Team <team@phalconphp.com>
 *
 * For the full copyright and license information, please view the LICENSE.txt
 * file that was distributed with this source code.
 */

namespace Phalcon\Mvc;

use Phalcon\DiInterface;
use Phalcon\Di\Injectable;
use Phalcon\Mvc\View\Exception;
use Phalcon\Mvc\ViewInterface;
use Phalcon\Cache\BackendInterface;
use Phalcon\Events\ManagerInterface;
use Phalcon\Mvc\View\Engine\Php as PhpEngine;

/**
 * Phalcon\Mvc\View
 *
 * Phalcon\Mvc\View is a class for working with the "view" portion of the model-view-controller pattern.
 * That is, it exists to help keep the view script separate from the model and controller scripts.
 * It provides a system of helpers, output filters, and variable escaping.
 *
 * <code>
 * use Phalcon\Mvc\View;
 *
 * $view = new View();
 *
 * // Setting views directory
 * $view->setViewsDir("app/views/");
 *
 * $view->start();
 *
 * // Shows recent posts view (app/views/posts/recent.phtml)
 * $view->render("posts", "recent");
 * $view->finish();
 *
 * // Printing views output
 * echo $view->getContent();
 * </code>
 */
class View extends Injectable implements ViewInterface
{
    /**
     * Cache Mode
     */
    const CACHE_MODE_NONE = 0;
    const CACHE_MODE_INVERSE = 1;

    /**
     * Render Level: To the action view
     */
    const LEVEL_ACTION_VIEW = 1;

    /**
     * Render Level: To the templates "before"
     */
    const LEVEL_BEFORE_TEMPLATE = 2;

    /**
     * Render Level: To the controller layout
     */
    const LEVEL_LAYOUT = 3;

    /**
     * Render Level: To the main layout
     */
    const LEVEL_MAIN_LAYOUT = 5;

    /**
     * Render Level: No render any view
     */
    const LEVEL_NO_RENDER = 0;

    /**
     * Render Level: Render to the templates "after"
     */
    const LEVEL_AFTER_TEMPLATE = 4;

    protected actionName;
    protected activeRenderPaths;
    protected basePath = "";
    protected cache;
    protected cacheLevel = 0;
    protected content = "";
    protected controllerName;
    protected currentRenderLevel = 0 { get };
    protected disabled = false;
    protected disabledLevels;
    protected engines = false;
    protected layout;
    protected layoutsDir = "";
    protected mainView = "index";
    protected options = [];
    protected params;
    protected pickView;
    protected partialsDir = "";
    protected registeredEngines = [] { get };
    protected renderLevel = 5 { get };
    protected templatesAfter = [];
    protected templatesBefore = [];
    protected viewsDirs = [];
    protected viewParams = [];

    /**
     * Phalcon\Mvc\View constructor
     */
    public function __construct(array options = [])
    {
        let this->options = options;
    }

    /**
     * Magic method to retrieve a variable passed to the view
     *
     *<code>
     * echo $this->view->products;
     *</code>
     */
    public function __get(string! key) -> var | null
    {
        var value;
        if fetch value, this->viewParams[key] {
            return value;
        }
        return null;
    }

    /**
     * Magic method to retrieve if a variable is set in the view
     *
     *<code>
     * echo isset($this->view->products);
     *</code>
     */
    public function __isset(string! key) -> bool
    {
        return isset this->viewParams[key];
    }

    /**
     * Magic method to pass variables to the views
     *
     *<code>
     * $this->view->products = $products;
     *</code>
     */
    public function __set(string! key, var value)
    {
        let this->viewParams[key] = value;
    }

    /**
     * Cache the actual view render to certain level
     *
     *<code>
     * $this->view->cache(
     *     [
     *         "key"      => "my-key",
     *         "lifetime" => 86400,
     *     ]
     * );
     *</code>
     */
    public function cache(var options = true) -> <View>
    {
        var viewOptions, cacheOptions, key, value, cacheLevel;

        if typeof options == "array" {

            let viewOptions = this->options;
            if typeof viewOptions != "array" {
                let viewOptions = [];
            }

            /**
             * Get the default cache options
             */
            if !fetch cacheOptions, viewOptions["cache"] {
                let cacheOptions = [];
            }

            for key, value in options {
                let cacheOptions[key] = value;
            }

            /**
             * Check if the user has defined a default cache level or use self::LEVEL_MAIN_LAYOUT as default
             */
            if fetch cacheLevel, cacheOptions["level"] {
                let this->cacheLevel = cacheLevel;
            } else {
                let this->cacheLevel = self::LEVEL_MAIN_LAYOUT;
            }

            let viewOptions["cache"] = cacheOptions;
            let this->options = viewOptions;
        } else {

            /**
             * If 'options' isn't an array we enable the cache with default options
             */
            if options {
                let this->cacheLevel = self::LEVEL_MAIN_LAYOUT;
            } else {
                let this->cacheLevel = self::LEVEL_NO_RENDER;
            }
        }

        return this;
    }

    /**
     * Resets any template before layouts
     */
    public function cleanTemplateAfter() -> <View>
    {
        let this->templatesAfter = [];
        return this;
    }

    /**
     * Resets any "template before" layouts
     */
    public function cleanTemplateBefore() -> <View>
    {
        let this->templatesBefore = [];
        return this;
    }

    /**
     * Disables a specific level of rendering
     *
     *<code>
     * // Render all levels except ACTION level
     * $this->view->disableLevel(
     *     View::LEVEL_ACTION_VIEW
     * );
     *</code>
     */
    public function disableLevel(var level) -> <ViewInterface>
    {
        if typeof level == "array" {
            let this->disabledLevels = level;
        } else {
            let this->disabledLevels[level] = true;
        }
        return this;
    }

    /**
     * Disables the auto-rendering process
     */
    public function disable() -> <View>
    {
        let this->disabled = true;
        return this;
    }

    /**
     * Enables the auto-rendering process
     */
    public function enable() -> <View>
    {
        let this->disabled = false;
        return this;
    }

    /**
     * Checks whether view exists
     */
    public function exists(string! view) -> bool
    {
        var basePath, viewsDir, engines, extension;

        let basePath = this->basePath,
            engines = this->registeredEngines;

        if empty engines {
            let engines = [".phtml": "Phalcon\\Mvc\\View\\Engine\\Php"];

            this->registerEngines(engines);
        }

        for viewsDir in this->getViewsDirs() {
            for extension, _ in engines {
                if file_exists(basePath . viewsDir . view . extension) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * Finishes the render process by stopping the output buffering
     */
    public function finish() -> <View>
    {
        ob_end_clean();
        return this;
    }

    /**
     * Gets the name of the action rendered
     */
    public function getActionName() -> string
    {
        return this->actionName;
    }

    /**
     * Returns the path (or paths) of the views that are currently rendered
     */
    public function getActiveRenderPath() -> string | array
    {
        var activeRenderPath;
        int viewsDirsCount;

        let viewsDirsCount = count(this->getViewsDirs()),
            activeRenderPath = this->activeRenderPaths;

        if viewsDirsCount === 1 {
            if typeof activeRenderPath == "array" {
                if count(activeRenderPath) {
                    let activeRenderPath = activeRenderPath[0];
                }
            }
        }

        if typeof activeRenderPath == "null" {
            let activeRenderPath = "";
        }

        return activeRenderPath;
    }

    /**
     * Gets base path
     */
    public function getBasePath() -> string
    {
        return this->basePath;
    }

    /**
     * Returns the cache instance used to cache
     */
    public function getCache() -> <BackendInterface>
    {
        if !this->cache || typeof this->cache != "object" {
            let this->cache = this->createCache();
        }

        return this->cache;
    }

    /**
     * Returns cached output from another view stage
     */
    public function getContent() -> string
    {
        return this->content;
    }

    /**
     * Gets the name of the controller rendered
     */
    public function getControllerName() -> string
    {
        return this->controllerName;
    }

    /**
     * Returns the name of the main view
     */
    public function getLayout() -> string
    {
        return this->layout;
    }

    /**
     * Gets the current layouts sub-directory
     */
    public function getLayoutsDir() -> string
    {
        return this->layoutsDir;
    }

    /**
     * Returns the name of the main view
     */
    public function getMainView() -> string
    {
        return this->mainView;
    }

    /**
     * Returns parameters to views
     */
    public function getParamsToView() -> array
    {
        return this->viewParams;
    }

    /**
     * Renders a partial view
     *
     * <code>
     * // Retrieve the contents of a partial
     * echo $this->getPartial("shared/footer");
     * </code>
     *
     * <code>
     * // Retrieve the contents of a partial with arguments
     * echo $this->getPartial(
     *     "shared/footer",
     *     [
     *         "content" => $html,
     *     ]
     * );
     * </code>
     */
    public function getPartial(string! partialPath, var params = null) -> string
    {
        // not liking the ob_* functions here, but it will greatly reduce the
        // amount of double code.
        ob_start();
        this->partial(partialPath, params);
        return ob_get_clean();
    }

    /**
     * Gets the current partials sub-directory
     */
    public function getPartialsDir() -> string
    {
        return this->partialsDir;
    }

    /**
     * Perform the automatic rendering returning the output as a string
     *
     * <code>
     * $template = $this->view->getRender(
     *     "products",
     *     "show",
     *     [
     *         "products" => $products,
     *     ]
     * );
     * </code>
     *
     * @param mixed configCallback
     */
    public function getRender(string! controllerName, string! actionName, array params = [], configCallback = null) -> string
    {
        var view;

        /**
         * We must to clone the current view to keep the old state
         */
        let view = clone this;

        /**
         * The component must be reset to its defaults
         */
        view->reset();

        /**
         * Set the render variables
         */
        if typeof params == "array" {
            view->setVars(params);
        }

        /**
         * Perform extra configurations over the cloned object
         */
        if typeof configCallback == "object" {
            call_user_func_array(configCallback, [view]);
        }

        /**
         * Start the output buffering
         */
        view->start();

        /**
         * Perform the render passing only the controller and action
         */
        view->render(controllerName, actionName);

        /**
         * Stop the output buffering
         */
        ob_end_clean();

        /**
         * Get the processed content
         */
        return view->getContent();
    }

    /**
     * Returns a parameter previously set in the view
     */
    public function getVar(string! key)
    {
        var value;

        if !fetch value, this->viewParams[key] {
            return null;
        }

        return value;
    }

    /**
     * Gets views directory
     */
    public function getViewsDir() -> string | array
    {
        return this->viewsDirs;
    }

    /**
     * Gets views directories
     */
    protected function getViewsDirs() -> array
    {
        if typeof this->viewsDirs === "string" {
            return [this->viewsDirs];
        }

        return this->viewsDirs;
    }

    /**
     * Check if the component is currently caching the output content
     */
    public function isCaching() -> bool
    {
        return this->cacheLevel > 0;
    }

    /**
     * Whether automatic rendering is enabled
     */
    public function isDisabled() -> bool
    {
        return this->disabled;
    }

    /**
     * Renders a partial view
     *
     * <code>
     * // Show a partial inside another view
     * $this->partial("shared/footer");
     * </code>
     *
     * <code>
     * // Show a partial inside another view with parameters
     * $this->partial(
     *     "shared/footer",
     *     [
     *         "content" => $html,
     *     ]
     * );
     * </code>
     */
    public function partial(string! partialPath, var params = null)
    {
        var viewParams;

        /**
         * If the developer pass an array of variables we create a new virtual symbol table
         */
        if typeof params == "array" {

            /**
             * Merge the new params as parameters
             */
            let viewParams = this->viewParams;
            let this->viewParams = array_merge(viewParams, params);

            /**
             * Create a virtual symbol table
             */
            create_symbol_table();
        }

        /**
         * Partials are looked up under the partials directory
         * We need to check if the engines are loaded first, this method could be called outside of 'render'
         * Call engine render, this checks in every registered engine for the partial
         */
        this->engineRender(this->loadTemplateEngines(), this->partialsDir . partialPath, false, false);

        /**
         * Now we need to restore the original view parameters
         */
        if typeof params == "array" {
            /**
             * Restore the original view params
             */
            let this->viewParams = viewParams;
        }
    }

    /**
     * Choose a different view to render instead of last-controller/last-action
     *
     * <code>
     * use Phalcon\Mvc\Controller;
     *
     * class ProductsController extends Controller
     * {
     *    public function saveAction()
     *    {
     *         // Do some save stuff...
     *
     *         // Then show the list view
     *         $this->view->pick("products/list");
     *    }
     * }
     * </code>
     */
    public function pick(var renderView) -> <View>
    {
        var pickView, layout, parts;

        if typeof renderView == "array" {
            let pickView = renderView;
        } else {

            let layout = null;
            if memstr(renderView, "/") {
                let parts = explode("/", renderView), layout = parts[0];
            }

            let pickView = [renderView];
            if layout !== null {
                let pickView[] = layout;
            }
        }

        let this->pickView = pickView;
        return this;
    }

    /**
     * Register templating engines
     *
     * <code>
     * $this->view->registerEngines(
     *     [
     *         ".phtml" => "Phalcon\\Mvc\\View\\Engine\\Php",
     *         ".volt"  => "Phalcon\\Mvc\\View\\Engine\\Volt",
     *         ".mhtml" => "MyCustomEngine",
     *     ]
     * );
     * </code>
     */
    public function registerEngines(array! engines) -> <View>
    {
        let this->registeredEngines = engines;
        return this;
    }

    /**
     * Executes render process from dispatching data
     *
     *<code>
     * // Shows recent posts view (app/views/posts/recent.phtml)
     * $view->start()->render("posts", "recent")->finish();
     *</code>
     */
    public function render(string! controllerName, string! actionName, array params = []) -> <View> | bool
    {
        bool silence, mustClean;
        int renderLevel;
        var layoutsDir, layout, pickView, layoutName,
            engines, renderView, pickViewAction, eventsManager,
            disabledLevels, templatesBefore, templatesAfter,
            templateBefore, templateAfter, cache;

        let this->currentRenderLevel = 0;

        /**
         * If the view is disabled we simply update the buffer from any output produced in the controller
         */
        if this->disabled !== false {
            let this->content = ob_get_contents();
            return false;
        }

        let this->controllerName = controllerName,
            this->actionName = actionName;

        if typeof params == "array" {
            this->setVars(params);
        }

        /**
         * Check if there is a layouts directory set
         */
        let layoutsDir = this->layoutsDir;
        if !layoutsDir {
            let layoutsDir = "layouts/";
        }

        /**
         * Check if the user has defined a custom layout
         */
        let layout = this->layout;
        if layout {
            let layoutName = layout;
        } else {
            let layoutName = controllerName;
        }

        /**
         * Load the template engines
         */
        let engines = this->loadTemplateEngines();

        /**
         * Check if the user has picked a view different than the automatic
         */
        let pickView = this->pickView;

        if pickView === null {
            let renderView = controllerName . "/" . actionName;
        } else {

            /**
             * The 'picked' view is an array, where the first element is controller and the second the action
             */
            let renderView = pickView[0];
            if layoutName === null {
                if fetch pickViewAction, pickView[1] {
                    let layoutName = pickViewAction;
                }
            }
        }

        /**
         * Start the cache if there is a cache level enabled
         */
        if this->cacheLevel {
            let cache = this->getCache();
        } else {
            let cache = null;
        }

        let eventsManager = <ManagerInterface> this->eventsManager;

        /**
         * Create a virtual symbol table.
         * Variables are shared across symbol tables in PHP5
         */
        create_symbol_table();

        /**
         * Call beforeRender if there is an events manager
         */
        if typeof eventsManager == "object" {
            if eventsManager->fire("view:beforeRender", this) === false {
                return false;
            }
        }

        /**
         * Get the current content in the buffer maybe some output from the controller?
         */
        let this->content = ob_get_contents();

        let mustClean = true,
            silence = true;

        /**
         * Disabled levels allow to avoid an specific level of rendering
         */
        let disabledLevels = this->disabledLevels;

        /**
         * Render level will tell use when to stop
         */
        let renderLevel = (int) this->renderLevel;
        if renderLevel {

            /**
             * Inserts view related to action
             */
            if renderLevel >= self::LEVEL_ACTION_VIEW {
                if !isset disabledLevels[self::LEVEL_ACTION_VIEW] {
                    let this->currentRenderLevel = self::LEVEL_ACTION_VIEW;
                    this->engineRender(engines, renderView, silence, mustClean, cache);
                }
            }

            /**
             * Inserts templates before layout
             */
            if renderLevel >= self::LEVEL_BEFORE_TEMPLATE  {
                if !isset disabledLevels[self::LEVEL_BEFORE_TEMPLATE] {
                    let this->currentRenderLevel = self::LEVEL_BEFORE_TEMPLATE;

                    let templatesBefore = this->templatesBefore;

                    let silence = false;
                    for templateBefore in templatesBefore {
                        this->engineRender(engines, layoutsDir . templateBefore, silence, mustClean, cache);
                    }
                    let silence = true;
                }
            }

            /**
             * Inserts controller layout
             */
            if renderLevel >= self::LEVEL_LAYOUT {
                if !isset disabledLevels[self::LEVEL_LAYOUT] {
                    let this->currentRenderLevel = self::LEVEL_LAYOUT;
                    this->engineRender(engines, layoutsDir . layoutName, silence, mustClean, cache);
                }
            }

            /**
             * Inserts templates after layout
             */
            if renderLevel >= self::LEVEL_AFTER_TEMPLATE {
                if !isset disabledLevels[self::LEVEL_AFTER_TEMPLATE] {
                    let this->currentRenderLevel = self::LEVEL_AFTER_TEMPLATE;

                    let templatesAfter = this->templatesAfter;

                    let silence = false;
                    for templateAfter in templatesAfter {
                        this->engineRender(engines, layoutsDir . templateAfter, silence, mustClean, cache);
                    }
                    let silence = true;
                }
            }

            /**
             * Inserts main view
             */
            if renderLevel >= self::LEVEL_MAIN_LAYOUT {
                if !isset disabledLevels[self::LEVEL_MAIN_LAYOUT] {
                    let this->currentRenderLevel = self::LEVEL_MAIN_LAYOUT;
                    this->engineRender(engines, this->mainView, silence, mustClean, cache);
                }
            }

            let this->currentRenderLevel = 0;

            /**
             * Store the data in the cache
             */
            if typeof cache == "object" {
                if cache->isStarted() && cache->isFresh() {
                    cache->save();
                } else {
                    cache->stop();
                }
            }
        }

        /**
         * Call afterRender event
         */
        if typeof eventsManager == "object" {
            eventsManager->fire("view:afterRender", this);
        }

        return this;
    }

    /**
     * Resets the view component to its factory default values
     */
    public function reset() -> <View>
    {
        let this->disabled = false,
            this->engines = false,
            this->cache = null,
            this->renderLevel = self::LEVEL_MAIN_LAYOUT,
            this->cacheLevel = self::LEVEL_NO_RENDER,
            this->content = null,
            this->templatesBefore = [],
            this->templatesAfter = [];
        return this;
    }

    /**
     * Sets base path. Depending of your platform, always add a trailing slash or backslash
     *
     * <code>
     *     $view->setBasePath(__DIR__ . "/");
     * </code>
     */
    public function setBasePath(string basePath) -> <View>
    {
        let this->basePath = basePath;
        return this;
    }

    /**
     * Externally sets the view content
     *
     *<code>
     * $this->view->setContent("<h1>hello</h1>");
     *</code>
     */
    public function setContent(string content) -> <View>
    {
        let this->content = content;
        return this;
    }

    /**
     * Change the layout to be used instead of using the name of the latest controller name
     *
     * <code>
     * $this->view->setLayout("main");
     * </code>
     */
    public function setLayout(string layout) -> <View>
    {
        let this->layout = layout;
        return this;
    }

    /**
     * Sets the layouts sub-directory. Must be a directory under the views directory.
     * Depending of your platform, always add a trailing slash or backslash
     *
     *<code>
     * $view->setLayoutsDir("../common/layouts/");
     *</code>
     */
    public function setLayoutsDir(string layoutsDir) -> <View>
    {
        let this->layoutsDir = layoutsDir;
        return this;
    }

    /**
     * Sets default view name. Must be a file without extension in the views directory
     *
     * <code>
     * // Renders as main view views-dir/base.phtml
     * $this->view->setMainView("base");
     * </code>
     */
    public function setMainView(string viewPath) -> <View>
    {
        let this->mainView = viewPath;
        return this;
    }

    /**
     * Sets a partials sub-directory. Must be a directory under the views directory.
     * Depending of your platform, always add a trailing slash or backslash
     *
     *<code>
     * $view->setPartialsDir("../common/partials/");
     *</code>
     */
    public function setPartialsDir(string partialsDir) -> <View>
    {
        let this->partialsDir = partialsDir;
        return this;
    }

    /**
     * Adds parameters to views (alias of setVar)
     *
     *<code>
     * $this->view->setParamToView("products", $products);
     *</code>
     */
    public function setParamToView(string! key, var value) -> <View>
    {
        let this->viewParams[key] = value;
        return this;
    }

    /**
     * Sets the render level for the view
     *
     * <code>
     * // Render the view related to the controller only
     * $this->view->setRenderLevel(
     *     View::LEVEL_LAYOUT
     * );
     * </code>
     */
    public function setRenderLevel(int level) -> <ViewInterface>
    {
        let this->renderLevel = level;
        return this;
    }

    /**
     * Sets a "template after" controller layout
     */
    public function setTemplateAfter(var templateAfter) -> <View>
    {
        if typeof templateAfter != "array" {
            let this->templatesAfter = [templateAfter];
        } else {
            let this->templatesAfter = templateAfter;
        }
        return this;
    }

    /**
     * Sets a template before the controller layout
     */
    public function setTemplateBefore(var templateBefore) -> <View>
    {
        if typeof templateBefore != "array" {
            let this->templatesBefore = [templateBefore];
        } else {
            let this->templatesBefore = templateBefore;
        }
        return this;
    }

    /**
     * Set a single view parameter
     *
     *<code>
     * $this->view->setVar("products", $products);
     *</code>
     */
    public function setVar(string! key, var value) -> <View>
    {
        let this->viewParams[key] = value;
        return this;
    }

    /**
     * Set all the render params
     *
     *<code>
     * $this->view->setVars(
     *     [
     *         "products" => $products,
     *     ]
     * );
     *</code>
     */
    public function setVars(array! params, bool merge = true) -> <View>
    {
        if merge {
            let this->viewParams = array_merge(this->viewParams, params);
        } else {
            let this->viewParams = params;
        }

        return this;
    }

    /**
     * Sets the views directory. Depending of your platform,
     * always add a trailing slash or backslash
     */
    public function setViewsDir(var viewsDir) -> <View>
    {
        var position, directory, directorySeparator, newViewsDir;

        if typeof viewsDir != "string" && typeof viewsDir != "array" {
            throw new Exception("Views directory must be a string or an array");
        }

        let directorySeparator = DIRECTORY_SEPARATOR;
        if typeof viewsDir == "string" {

            if substr(viewsDir, -1) != directorySeparator {
                let viewsDir = viewsDir . directorySeparator;
            }

            let this->viewsDirs = viewsDir;
        } else {

            let newViewsDir = [];
            for position, directory in viewsDir {

                if typeof directory != "string" {
                    throw new Exception("Views directory item must be a string");
                }

                if substr(directory, -1) != directorySeparator {
                    let newViewsDir[position] = directory . directorySeparator;
                } else {
                    let newViewsDir[position] = directory;
                }
            }

            let this->viewsDirs = newViewsDir;
        }

        return this;
    }

    /**
     * Starts rendering process enabling the output buffering
     */
    public function start() -> <View>
    {
        ob_start();
        let this->content = null;
        return this;
    }

    /**
     * Create a Phalcon\Cache based on the internal cache options
     */
    protected function createCache() -> <BackendInterface>
    {
        var container, cacheService, viewCache,
            viewOptions, cacheOptions;

        let container = <DiInterface> this->container;
        if typeof container != "object" {
            throw new Exception(Exception::containerServiceNotFound("the view cache services"));
        }

        let cacheService = "viewCache";

        let viewOptions = this->options;

        if fetch cacheOptions, viewOptions["cache"] {
            if isset cacheOptions["service"] {
                let cacheService = cacheOptions["service"];
            }
        }

        /**
         * The injected service must be an object
         */
        let viewCache = <BackendInterface> container->getShared(cacheService);
        if typeof viewCache != "object" {
            throw new Exception("The injected caching service is invalid");
        }

        return viewCache;
    }

    /**
     * Checks whether view exists on registered extensions and render it
     */
    protected function engineRender(array engines, string viewPath, bool silence, bool mustClean, <BackendInterface> cache = null)
    {
        bool notExists;
        int renderLevel, cacheLevel;
        var key, lifetime, viewsDir, basePath, viewsDirPath,
            viewOptions, cacheOptions, cachedView, viewParams, eventsManager,
            extension, engine, viewEnginePath, viewEnginePaths;

        let notExists = true,
            basePath = this->basePath,
            viewParams = this->viewParams,
            eventsManager = <ManagerInterface> this->eventsManager,
            viewEnginePaths = [];

        for viewsDir in this->getViewsDirs() {

            if !this->isAbsolutePath(viewPath) {
                let viewsDirPath = basePath . viewsDir . viewPath;
            } else {
                let viewsDirPath = viewPath;
            }

            if typeof cache == "object" {

                let renderLevel = (int) this->renderLevel,
                    cacheLevel = (int) this->cacheLevel;

                if renderLevel >= cacheLevel {

                    /**
                     * Check if the cache is started, the first time a cache is started we start the
                     * cache
                     */
                    if !cache->isStarted() {

                        let key = null,
                            lifetime = null;

                        let viewOptions = this->options;

                        /**
                         * Check if the user has defined a different options to the default
                         */
                        if fetch cacheOptions, viewOptions["cache"] {
                            if typeof cacheOptions == "array" {
                                fetch key, cacheOptions["key"];
                                fetch lifetime, cacheOptions["lifetime"];
                            }
                        }

                        /**
                         * If a cache key is not set we create one using a md5
                         */
                        if key === null {
                            let key = md5(viewPath);
                        }

                        /**
                         * We start the cache using the key set
                         */
                        let cachedView = cache->start(key, lifetime);
                        if cachedView !== null {
                            let this->content = cachedView;
                            return null;
                        }
                    }

                    /**
                     * This method only returns true if the cache has not expired
                     */
                    if !cache->isFresh() {
                        return null;
                    }
                }
            }

            /**
             * Views are rendered in each engine
             */
            for extension, engine in engines {

                let viewEnginePath = viewsDirPath . extension;
                if file_exists(viewEnginePath) {

                    /**
                     * Call beforeRenderView if there is an events manager available
                     */
                    if typeof eventsManager == "object" {
                        let this->activeRenderPaths = [viewEnginePath];
                        if eventsManager->fire("view:beforeRenderView", this, viewEnginePath) === false {
                            continue;
                        }
                    }

                    engine->render(viewEnginePath, viewParams, mustClean);

                    /**
                     * Call afterRenderView if there is an events manager available
                     */
                    let notExists = false;
                    if typeof eventsManager == "object" {
                        eventsManager->fire("view:afterRenderView", this);
                    }
                    break;
                }

                let viewEnginePaths[] = viewEnginePath;
            }
        }

        if notExists === true {
            /**
             * Notify about not found views
             */
            if typeof eventsManager == "object" {
                let this->activeRenderPaths = viewEnginePaths;
                eventsManager->fire("view:notFoundView", this, viewEnginePath);
            }

            if !silence {
                throw new Exception("View '" . viewPath . "' was not found in any of the views directory");
            }
        }
    }

    /**
     * Checks if a path is absolute or not
     */
    protected final function isAbsolutePath(string path)
    {
        if PHP_OS == "WINNT" {
            return strlen(path) >= 3 && path[1] == ':' && path[2] == '\\';
        }

        return strlen(path) >= 1 && path[0] == '/';
    }
    /**
     * Loads registered template engines, if none is registered it will use Phalcon\Mvc\View\Engine\Php
     */
    protected function loadTemplateEngines() -> array
    {
        var engines, di, registeredEngines, engineService, extension;

        let engines = this->engines;

        /**
         * If the engines aren't initialized 'engines' is false
         */
        if engines === false {

            let di = <DiInterface> this->container;

            let engines = [];
            let registeredEngines = this->registeredEngines;
            if empty registeredEngines {

                /**
                 * We use Phalcon\Mvc\View\Engine\Php as default
                 */
                let engines[".phtml"] = new PhpEngine(this, di);
            } else {

                if typeof di != "object" {
                    throw new Exception(Exception::containerServiceNotFound("application services"));
                }

                for extension, engineService in registeredEngines {

                    if typeof engineService == "object" {

                        /**
                         * Engine can be a closure
                         */
                        if engineService instanceof \Closure {
                            let engineService = \Closure::bind(engineService, di);
                            let engines[extension] = call_user_func(engineService, this);
                        } else {
                            let engines[extension] = engineService;
                        }

                    } else {

                        /**
                         * Engine can be a string representing a service in the DI
                         */
                        if typeof engineService != "string" {
                            throw new Exception("Invalid template engine registration for extension: " . extension);
                        }

                        let engines[extension] = di->getShared(engineService, [this]);
                    }
                }
            }

            let this->engines = engines;
        }

        return engines;
    }
}