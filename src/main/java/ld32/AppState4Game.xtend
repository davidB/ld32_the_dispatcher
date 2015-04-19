package ld32

import jme3_ext.AppState0

class AppState4Game extends AppState0 {

	public GameRun game

	override protected doInitialize() {
		val gamedata = new GameData()
		gamedata.loadData(app.assetManager)
		game = new GameRun(gamedata)
	}

	override protected doUpdate(float tpf) {
		game.updateNpcLife(0.1f)
	}

}