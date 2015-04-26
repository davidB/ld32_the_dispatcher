package ld32

import com.jme3.collision.CollisionResults
import com.jme3.cursors.plugins.JmeCursor
import com.jme3.input.KeyInput
import com.jme3.input.MouseInput
import com.jme3.input.controls.ActionListener
import com.jme3.input.controls.KeyTrigger
import com.jme3.input.controls.MouseButtonTrigger
import com.jme3.light.AmbientLight
import com.jme3.light.DirectionalLight
import com.jme3.material.Material
import com.jme3.math.ColorRGBA
import com.jme3.math.FastMath
import com.jme3.math.Quaternion
import com.jme3.math.Ray
import com.jme3.math.Vector2f
import com.jme3.math.Vector3f
import com.jme3.post.FilterPostProcessor
import com.jme3.renderer.RenderManager
import com.jme3.renderer.ViewPort
import com.jme3.renderer.queue.RenderQueue.ShadowMode
import com.jme3.scene.Geometry
import com.jme3.scene.Node
import com.jme3.scene.Spatial
import com.jme3.scene.control.AbstractControl
import com.jme3.scene.shape.Quad
import com.jme3.scene.shape.Sphere
import com.jme3.shadow.DirectionalLightShadowFilter
import com.jme3.util.SkyFactory
import java.net.URL
import java.util.ResourceBundle
import javafx.animation.FadeTransition
import javafx.application.Platform
import javafx.fxml.FXML
import javafx.fxml.Initializable
import javafx.scene.control.Button
import javafx.scene.control.Label
import javafx.scene.layout.StackPane
import javafx.util.Duration
import javax.inject.Inject
import jme3_ext.AppState0
import jme3_ext.Hud
import jme3_ext.HudTools
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

public class PageInGame extends AppState0 {
	val HudInGame hudController
	val HudTools hudTools
	// private final Commands controls;
	// private final InputMapper inputMapper;
	// private final Provider<PageManager> pm; // use Provider as Hack to break the dependency cycle PageManager -> Page -> PageManager
	// private final AppStateDeferredRendering appStateDeferredRendering;
	// private final AppStateDebug appStateDebug;
	// private final PageEnd pageEnd;
	// private final PageIntro pageIntro;

	var Hud<HudInGame> hud
	var GameRun game

	val scene = new Node("scene")
	val shootables = new Node("shootables")
	Spatial mark
	var countDown = 0

	@Inject
	@FinalFieldsConstructor
	new() {
	}

	override doInitialize() {
		hud = hudTools.newHud("Interface/HudInGame.fxml", hudController)
		// app.getStateManager().attach(pageIntro);
		// app.getStateManager().attach(appStateDeferredRendering);
		val gamedata = new GameData()
		gamedata.loadData(app.assetManager)
		game = new GameRun(gamedata)

		game.npcSpawn.subscribe[v|
			spawnNpc(shootables, v)
		]
		game.npcDespawn.subscribe[v|
			shootables.detachChildNamed(v.id)
			mark.removeFromParent()
			Platform.runLater[
				val label = switch(v.kind){
					case Npc.jock: hudController.restJock
					case Npc.nerd: hudController.restNerd
					case Npc.kid: hudController.restKid
					case Npc.rabbit: hudController.restRabbit
				}
				if (label != null) {
					val previous = Integer.parseInt(label.text)
					label.setText(String.format("%02d", previous + 1))
				}
			]
		]
		game.munitions.subscribe[v|
			Platform.runLater[
				for(p : v) {
					val str = String.format("%02d", p.value)
					switch(p.key){
						case Bullet.dumbbell: hudController.restDumbbell.setText(str)
						case Bullet.book: hudController.restBook.setText(str)
						case Bullet.candy: hudController.restCandy.setText(str)
						case Bullet.carrot: hudController.restCarrot.setText(str)
					}
				}
			]
		]
		game.scores.subscribe[v|
			Platform.runLater[
				hudController.score.setText(String.format("%04d", v.newScore))
				if (v.point != 0 && v.mult != 0) {
					hudController.notification.setText(String.format("%02d x %02d", v.point, v.mult))
					hudController.showNotification()
				}
			]
		]
		game.fire.subscribe[v|
			// 1. Reset results list.
			val results = new CollisionResults();
			// 2. Aim the ray from cam loc to cam direction.
			// Convert screen click to 3d position
			val click2d = app.inputManager.getCursorPosition()
			val click3d = app.camera.getWorldCoordinates(new Vector2f(click2d.x, click2d.y), 0f).clone()
			val dir = app.camera.getWorldCoordinates(new Vector2f(click2d.x, click2d.y), 1f).subtractLocal(click3d).normalizeLocal()
			//Aim the ray from the clicked spot forwards.
			val ray = new Ray(click3d, dir)
			// 3. Collect intersections between Ray and Shootables in results list.
			shootables.collideWith(ray, results)
			// 4. Print the results
			//System.out.println("----- Collisions? " + results.size() + "-----")
			for (var i = 0; i < results.size(); i++) {
				// For each hit, we know distance, impact point, name of geometry.
				//val dist = results.getCollision(i).getDistance()
				//val pt = results.getCollision(i).getContactPoint()
				//val hit = results.getCollision(i).getGeometry().getName()
				//System.out.println("* Collision #" + i)
				//System.out.println("  You shot " + hit + " at " + pt + ", " + dist + " wu away.")
			}
			// 5. Use the results (we mark the hit object)
			if (results.size() > 0) {
				// The closest collision point is what was truly hit:
				val closest = results.getClosestCollision()
				// Let's interact - we mark the hit with a red dot.
				mark.setLocalTranslation(closest.getContactPoint())
				//scene.attachChild(mark)
				val x = ((closest.getContactPoint().x + 2.5f) % 2.5f) * 0.5f
				val y = (closest.getContactPoint().y + 1f) * 0.5f
				game.hits.onNext(new Hit(closest.geometry.parent.name, new Vector2f(x,y), v.key))
			} else {
				// No hits? Then remove the red mark.
				scene.detachChild(mark)
			}
		]
		game.bullet.subscribe[v|
			Platform.runLater[
				for (w : #[hudController.btnDumbbell, hudController.btnBook, hudController.btnCandy, hudController.btnCarrot]) {
					w.styleClass.remove("selected")
				}
				switch(v){
					case Bullet.dumbbell: hudController.btnDumbbell.styleClass.add("selected")
					case Bullet.book: hudController.btnBook.styleClass.add("selected")
					case Bullet.candy: hudController.btnCandy.styleClass.add("selected")
					case Bullet.carrot: hudController.btnCarrot.styleClass.add("selected")
				}
			]
		]
//		hudController.retry.onAction = [a|
//			app.enqueue[
//				reset()
//				true
//			]
//		]
	}

//	def reset() {
//		doDisable()
//		doEnable()
//	}

//	def countDownDec() {
//		countDown -= 1
//		if (countDown <= 0) {
//			Platform.runLater[
//				hudController.retry.disable = false
//				hudController.retry.opacity = 1.0
//			]
//		}
//	}

	override doEnable() {
		Platform.runLater[
			hudController.retry.disable = true
			hudController.retry.opacity = 0.0
		]
		hudTools.show(hud);
//		app.getInputManager().addRawInputListener(inputMapper.rawInputListener);
//		FxPlatformExecutor.runOnFxApplication[
//			val p = hud.controller
//			p.quit.onActionProperty().set[v|
//				app.enqueue[|
//					app.stop()
//					return true
//				]
//			]
//		]
//		//inputMapper.last.subscribe((v) -> {System.out.println("last evt : " + v);});
//		inputSub = Subscriptions.from(
//				controls.exit.value.subscribe((v) -> {
//					if (!v) hud.controller.quit.fire();
//				})
//				, controls.moveX.value.subscribe((v) -> {c4t.speedX = v * speedMax;})
//				, controls.moveZ.value.subscribe((v) -> {c4t.speedZ = v * -speedMax;})
//				, controls.moveXN.value.subscribe((v) -> {c4t.speedXN = v * speedMax;})
//				, controls.moveZN.value.subscribe((v) -> {c4t.speedZN = v * -speedMax;})
//				, controls.moveX.value.subscribe((v) -> {if (v != 0) timeCount.start();})
//				, controls.moveZ.value.subscribe((v) -> {if (v != 0) timeCount.start();})
//				, controls.moveXN.value.subscribe((v) -> {if (v != 0) timeCount.start();})
//				, controls.moveZN.value.subscribe((v) -> {if (v != 0) timeCount.start();})
//				);
		val scene = makeScene();
		app.getRootNode().attachChild(scene);
		val cam = app.getViewPort().getCamera();
		// cam.setLocation(new Vector3f(0,3,-8).mult(0.8f));
		print(cam.location)
		cam.lookAt(scene.getWorldTranslation(), Vector3f.UNIT_Y);
		val cursor = app.assetManager.loadAsset("Textures/target.ico") as JmeCursor
		cursor.setxHotSpot(16)
		cursor.setyHotSpot(16);
		app.inputManager.setMouseCursor(cursor)
		initControls()


	// if (audioBg != null) {
	// audioBg.play();
	// }
	}

	override protected doUpdate(float tpf) {
		game.updateNpcLife(tpf)
	}

	override doDisable() {
		app.enqueue [
//			unspawnScene();
			return true;
		]
//		app.getInputManager().removeRawInputListener(inputMapper.rawInputListener);
		hudTools.hide(hud);
//		if (inputSub != null){
//			inputSub.unsubscribe();
//			inputSub = null;
//		}
	}

	override doDispose() {
		// TODO Auto-generated method stub
		super.doDispose();
	}

	def makeScene() {
		val sky = SkyFactory.createSky(app.assetManager, "Textures/sky1.jpg", true)
		sky.rotateUpTo(Vector3f.UNIT_Z)
		sky.setName("sky")
		scene.attachChild(sky)
		makeFloor(scene)
		makeLigths(scene)
		scene.attachChild(shootables)
		mark = makeMark()
		//spawnNpc(shootables, new NpcLifeDef(Npc.jock, 0, 0, "jock0"))
//		audioBg = makeAudioBg();
//		scene.attachChild(audioBg);
//		scene.attachChild(makeDrone());
		return scene;
	}

	def makeLigths(Node anchor) {
		val light0 = new AmbientLight();
		light0.setColor(new ColorRGBA(0.2f, 0.2f, 0.3f, 1.0f));
		anchor.addLight(light0);

		val light2 = new DirectionalLight()
		light2.setColor(new ColorRGBA(0.9f, 0.9f, 0.9f, 1.0f))
		light2.setDirection(new Vector3f(0.5f, -5f, -1.0f).normalizeLocal())
		light2.setName("ldir-floor")
		anchor.addLight(light2)

		val light1 = new DirectionalLight()
		light1.setColor(new ColorRGBA(0.9f, 0.9f, 0.9f, 1.0f))
		light1.setDirection(new Vector3f(0.5f, -5f, -5f).normalizeLocal())
		light1.setName("ldir")
		anchor.addLight(light1)

		val fpp = new FilterPostProcessor(app.assetManager);

		// Drop shadows
		val SHADOWMAP_SIZE = 1024;
//        val dlsr = new DirectionalLightShadowRenderer(assetManager, SHADOWMAP_SIZE, 3);
//        dlsr.setLight(sun);
//        viewPort.addProcessor(dlsr);
		val dlsf = new DirectionalLightShadowFilter(app.assetManager, SHADOWMAP_SIZE, 3);
		dlsf.setLight(light1);
		dlsf.setEnabled(true);
		dlsf.shadowIntensity = 0.7f
		fpp.addFilter(dlsf);

//        val ssaoFilter = new SSAOFilter(12.94f, 43.92f, 0.33f, 0.61f);
//		fpp.addFilter(ssaoFilter);
		app.viewPort.addProcessor(fpp);

	}

	def makeFloor(Node anchor) {
		val geom = new Geometry("floor", new Quad(500.0f, 500.0f))
		// geom.setLocalTranslation(-0.5f * 500.0f, -0.5f * 500.0f, -1.0f)
		geom.localRotation = new Quaternion().fromAngleAxis(-FastMath.PI / 2, Vector3f.UNIT_X)
		geom.setLocalTranslation(-0.5f * 500f, -1.1f, 20)

		val mat = new Material(app.assetManager, "Common/MatDefs/Light/Lighting.j3md")
		mat.setBoolean("UseMaterialColors", true)
		//mat.setBoolean("UseVertexColor", true)
		mat.setColor("Diffuse", new ColorRGBA(249f / 254f, 246 / 254f, 251f / 254f, 1.0f))
		// mat.setColor("Diffuse", ColorRGBA.White)

		//val mat = new Material(app.assetManager, "Common/MatDefs/Misc/Unshaded.j3md");
		//mat.setColor("Color", ColorRGBA.Red);

		geom.setMaterial(mat);
		geom.shadowMode = ShadowMode.Receive
		// geom.setQueueBucket(Bucket.Transparent);
		anchor.attachChild(geom)
	}

	def spawnNpc(Node anchor, NpcLifeDef npcdef) {
		val npc = makeNpc(npcdef.kind)
		npc.setName(npcdef.id)
		npc.localTranslation = new Vector3f((npcdef.place - 1) * 2.5f, 0, -50)
		npc.addControl(new AbstractControl() {
			val speed = 5f
			override protected controlRender(RenderManager rm, ViewPort vp) {
			}

			override protected controlUpdate(float tpf) {
				val loc = spatial.localTranslation.clone
				loc.z += tpf * speed
				spatial.localTranslation = loc
				if (loc.z > app.camera.location.z) {
					spatial.removeFromParent()
				}
			}

		})
		anchor.attachChild(npc)
	}

	def makeNpc(Npc npc) {
		val b = new Node("npc")
		val geom = new Geometry("card", new Quad(2.0f, 2.0f));
		geom.setLocalTranslation(-0.5f * 1.0f, -0.5f * 2.0f, 0.0f);
		val mat = new Material(app.assetManager, "Common/MatDefs/Light/Lighting.j3md")
		mat.setBoolean("UseMaterialColors", true)
		//mat.setBoolean("UseVertexColor", true) //black on macosx if enabled
		mat.setColor("Diffuse", ColorRGBA.White)
		mat.setTexture("DiffuseMap", app.assetManager.loadTexture("Textures/" + npc.name + "_512.png"))
		// mat.getAdditionalRenderState().setBlendMode(RenderState.BlendMode.Additive);
		// mat.getAdditionalRenderState().setDepthWrite(false);
		geom.setMaterial(mat);
		geom.shadowMode = ShadowMode.CastAndReceive
		// geom.setQueueBucket(Bucket.Transparent);
		b.attachChild(geom)
		b
	}

	def makeMark() {
		val sphere = new Sphere(30, 30, 0.2f);
		val mark = new Geometry("mark", sphere);
		val mat = new Material(app.assetManager, "Common/MatDefs/Misc/Unshaded.j3md");
		mat.setColor("Color", ColorRGBA.Red);
		mark.setMaterial(mat)
		mark
	}

	/** Declaring the "Shoot" action and mapping to its triggers. */
	def initControls() {
		app.inputManager.addMapping(
			"Shoot",
			new KeyTrigger(KeyInput.KEY_SPACE), // trigger 1: spacebar
			new MouseButtonTrigger(MouseInput.BUTTON_LEFT) // trigger 2: left-button click
		);
		app.inputManager.addMapping(
			"Dumbbell",
			new KeyTrigger(KeyInput.KEY_1),
			new KeyTrigger(KeyInput.KEY_NUMPAD1),
			new KeyTrigger(KeyInput.KEY_A),
			new KeyTrigger(KeyInput.KEY_Q)
		);
		app.inputManager.addMapping(
			"Book",
			new KeyTrigger(KeyInput.KEY_2),
			new KeyTrigger(KeyInput.KEY_NUMPAD2),
			new KeyTrigger(KeyInput.KEY_Z),
			new KeyTrigger(KeyInput.KEY_W)
		);
		app.inputManager.addMapping(
			"Candy",
			new KeyTrigger(KeyInput.KEY_3),
			new KeyTrigger(KeyInput.KEY_NUMPAD3),
			new KeyTrigger(KeyInput.KEY_E)
		);
		app.inputManager.addMapping(
			"Carrot",
			new KeyTrigger(KeyInput.KEY_4),
			new KeyTrigger(KeyInput.KEY_NUMPAD4),
			new KeyTrigger(KeyInput.KEY_R)
		);
		app.inputManager.addListener(actionListener, "Shoot", "Dumbbell", "Book", "Candy", "Carrot")
	}

	/** Defining the "Shoot" action: Determine what was hit and how to respond. */
	val actionListener = new ActionListener(){

		override onAction(String name, boolean isPressed, float tpf)  {
			if (!isPressed) {
				switch(name) {
					case "Shoot": game.reqFire.onNext(app.inputManager.getCursorPosition())
					case "Dumbbell": game.bullet.onNext(Bullet.dumbbell)
					case "Book": game.bullet.onNext(Bullet.book)
					case "Candy": game.bullet.onNext(Bullet.candy)
					case "Carrot": game.bullet.onNext(Bullet.carrot)
				}
			}
		}
	}
}

class HudInGame implements Initializable {
//	@FXML
//	public Region root;

	@FXML
	public Label score

	@FXML
	public Label notification

	@FXML
	public Label restDumbbell
	@FXML
	public Label touchDumbbell
	@FXML
	public StackPane btnDumbbell

	@FXML
	public Label restBook
	@FXML
	public Label touchBook
	@FXML
	public StackPane btnBook

	@FXML
	public Label restCandy
	@FXML
	public Label touchCandy
	@FXML
	public StackPane btnCandy

	@FXML
	public Label restCarrot
	@FXML
	public Label touchCarrot
	@FXML
	public StackPane btnCarrot

	@FXML
	public Label restJock
	@FXML
	public StackPane btnJock

	@FXML
	public Label restNerd
	@FXML
	public StackPane btnNerd

	@FXML
	public Label restKid
	@FXML
	public StackPane btnKid

	@FXML
	public Label restRabbit
	@FXML
	public StackPane btnRabbit

	@FXML
	public Button retry

	var FadeTransition ft

	override initialize(URL location, ResourceBundle resources) {
		//notification.setStyle("-fx-background-color: #EE0000;");
		touchDumbbell.setStyle("-fx-background-color: #EEEEFF;");
		touchBook.setStyle("-fx-background-color: #EEEEFF;");
		touchCandy.setStyle("-fx-background-color: #EEEEFF;");
		touchCarrot.setStyle("-fx-background-color: #EEEEFF;");
		//restDumbbell.setStyle("-fx-background-color: #EEEEFF;");
		ft = new FadeTransition(Duration.millis(500), notification);
		ft.setFromValue(0.0)
		ft.setToValue(1.0)
		ft.setCycleCount(2)
		ft.setAutoReverse(true)
	}

	def showNotification() {
		ft.play();
	}

}
