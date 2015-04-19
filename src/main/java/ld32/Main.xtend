package ld32

import com.google.inject.AbstractModule
import com.google.inject.Guice
import com.google.inject.Provides
import com.jme3.app.FlyCamAppState
import com.jme3.app.SimpleApplication
import com.jme3.system.AppSettings
import com.jme3x.jfx.FxPlatformExecutor
import com.jme3x.jfx.GuiManager
import com.jme3x.jfx.cursor.ICursorDisplayProvider
import com.jme3x.jfx.cursor.proton.ProtonCursorProvider
import com.sun.javafx.application.PlatformImpl
import java.util.Locale
import java.util.ResourceBundle
import java.util.concurrent.CountDownLatch
import javafx.application.Platform
import javafx.fxml.FXMLLoader
import javafx.fxml.JavaFXBuilderFactory
import javafx.scene.text.Font
import javax.inject.Singleton
import jme3_ext.AppSettingsLoader

class Main {
	static def void main(String[] args) {
		main1(args)
	}

	static def void main0(String[] args) {
		val game = new GameRun(new GameData())
		for(var i = 0f; i < 20f; i += 0.1f) {
			game.updateNpcLife(0.1f)
		}
	}

	static def void main1(String[] args) {
		val gameModule = new GameModule()
		val injector = Guice.createInjector(gameModule)
		gameModule.initJfx()
		val jmeapp = injector.getInstance(typeof(SimpleApplication))
		jmeapp.enqueue([|
			val pageInGame = injector.getInstance(typeof(PageInGame))
			jmeapp.stateManager.attach(pageInGame)
			null
		])
	}
}

public class GameModule extends AbstractModule {
	def jmeapp() {
		initJfx()
		simpleApplication(appSettings(appSettingsLoader(), resources(locale())))
	}

	@Provides
	def AppSettingsLoader appSettingsLoader() {
		new AppSettingsLoader() {
			val prefKey = "ld32"

			override AppSettings loadInto(AppSettings settings) {
				settings.load(prefKey);
				return settings;
			}

			override AppSettings save(AppSettings settings) {
				settings.save(prefKey);
				return settings;
			}
		};
	}

	@Singleton
	@Provides
	def SimpleApplication simpleApplication(AppSettings appSettings) {
		//HACK
		val initializedSignal = new CountDownLatch(1);
		val app = new SimpleApplication(){
			override simpleInitApp() {
				flyCam.setEnabled(false);
				stateManager.detach(stateManager.getState(typeof(FlyCamAppState)))
				initializedSignal.countDown();
			}

			override destroy() {
				super.destroy();
				FxPlatformExecutor.runOnFxApplication[|
					Platform.exit();
				]
			}
		};
		app.setSettings(appSettings);
		app.setShowSettings(false);
		app.setDisplayStatView(false);
		app.setDisplayFps(false);
		app.start();
		try {
			initializedSignal.await();
		} catch (InterruptedException e) {
			e.printStackTrace();
		}
		return app;
	}

	@Singleton
	@Provides
	def AppSettings appSettings(AppSettingsLoader appSettingsLoader, ResourceBundle resources) {
		var settings = new AppSettings(true);
		try {
			settings = appSettingsLoader.loadInto(settings);
		} catch (Exception e) {
			e.printStackTrace();
		}
		settings.setTitle(resources.getString("title"));
		settings.setUseJoysticks(false);
		//settings.setGammaCorrection(true); //TODO jme 3.1.0
		settings.setResolution(1280, 720);
		settings.setVSync(false);
		settings.setFullscreen(false);
		//settings.setDepthBits(24);
		//settings.setCustomRenderer(LwjglDisplayCustom.class);
		return settings;
	}

	@Provides
	def FXMLLoader fxmlLoader(ResourceBundle resources) {
		val fxmlLoader = new FXMLLoader();
		fxmlLoader.setResources(resources);
		fxmlLoader.setBuilderFactory(new JavaFXBuilderFactory());
		return fxmlLoader;
	}

	@Singleton
	@Provides
	def Locale locale() {
		return Locale.getDefault();
	}

	@Provides
	def ResourceBundle resources(Locale locale) {
		return ResourceBundle.getBundle("Interface.labels", locale);
	}

	def initJfx() {
		//new JFXPanel();
		// Note that calling PlatformImpl.startup more than once is OK
		PlatformImpl.startup[|
			//initJfxStyle()
		]
	}
/*
	//HACK: workaround see https://bitbucket.org/controlsfx/controlsfx/issue/370/using-controlsfx-causes-css-errors-and
	//@SuppressWarnings({"rawtypes", "unchecked"})
	def initJfxStyle() {
		//use reflection because sun.util.logging.PlatformLogger.Level is not always available
		try {
			//com.sun.javafx.Logging.getCSSLogger().setLevel(sun.util.logging.PlatformLogger.Level.SEVERE);
			val Class<Enum<?>> e = Class.forName("sun.util.logging.PlatformLogger$Level")
			val o = Class.forName("com.sun.javafx.Logging").getMethod("getCSSLogger").invoke(null)
			o.getClass().getMethod("setLevel", e).invoke(o, Enum.valueOf(e, "SEVERE"));
		} catch(Exception exc) {
			exc.printStackTrace();
		}
//		StyleManager.getInstance().addUserAgentStylesheet(Thread.currentThread().getContextClassLoader().getResource( "com/sun/javafx/scene/control/skin/modena/modena.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(GlyphFont.class.getResource("glyphfont.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(CommandLinksDialog.class.getResource("commandlink.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(Dialogs.class.getResource("dialogs.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(Wizard.class.getResource("wizard.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(CustomTextField.class.getResource("customtextfield.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(CustomTextField.class.getResource("autocompletion.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(SpreadsheetView.class.getResource("spreadsheet.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(PropertySheet.class.getResource("breadcrumbbar.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(PropertySheet.class.getResource("gridview.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(PropertySheet.class.getResource("info-overlay.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(PropertySheet.class.getResource("listselectionview.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(PropertySheet.class.getResource("masterdetailpane.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(PropertySheet.class.getResource("notificationpane.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(PropertySheet.class.getResource("notificationpopup.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(PropertySheet.class.getResource("plusminusslider.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(PropertySheet.class.getResource("popover.bss").toExternalForm());
		StyleManager.getInstance().addUserAgentStylesheet(typeof(PropertySheet).getResource("propertysheet.css").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(PropertySheet.class.getResource("rangeslider.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(PropertySheet.class.getResource("rating.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(PropertySheet.class.getResource("segmentedbutton.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(PropertySheet.class.getResource("snapshot-view.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(PropertySheet.class.getResource("statusbar.bss").toExternalForm());
//		StyleManager.getInstance().addUserAgentStylesheet(PropertySheet.class.getResource("taskprogressview.bss").toExternalForm());
	}
	*/

	def initGui(GuiManager guiManager) {
		//see http://blog.idrsolutions.com/2014/04/use-external-css-files-javafx/
		val scene = guiManager.getjmeFXContainer().getScene();
		FxPlatformExecutor.runOnFxApplication[|
			Font.loadFont(typeof(Main).getResource("/Fonts/KeyCapsFLF.ttf").toExternalForm(), 10);
			Font.loadFont(typeof(Main).getResource("/Fonts/soupofjustice.ttf").toExternalForm(), 10);
			val css = typeof(Main).getResource("/Interface/main.css").toExternalForm();
			scene.getStylesheets().clear();
			scene.getStylesheets().add(css);
		]
	}

	@Provides
	@Singleton
	def ICursorDisplayProvider cursorDisplayProvider(SimpleApplication app) {
		return new ProtonCursorProvider(app, app.getAssetManager(), app.getInputManager());
	}

	@Provides
	@Singleton
	def guiManager(SimpleApplication app, ICursorDisplayProvider c) {
		try {
			//guiManager modify app.guiNode so it should run in JME Thread
			val guiManager = new GuiManager(app.getGuiNode(), app.getAssetManager(), app, true, null);
			app.getInputManager().addRawInputListener(guiManager.getInputRedirector());
			initGui(guiManager)
			return guiManager;
		} catch (RuntimeException e) {
			throw e;
		} catch (Exception e) {
			throw new RuntimeException(e.getMessage(), e);
		}
	}

	override protected configure() {
	}

}