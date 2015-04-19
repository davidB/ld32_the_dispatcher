package ld32

import com.jme3.asset.AssetManager
import com.jme3.math.FastMath
import com.jme3.math.Vector2f
import com.jme3.texture.image.ImageRaster
import java.util.ArrayList
import java.util.LinkedList
import java.util.Random
import java.util.concurrent.atomic.AtomicInteger
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtext.xbase.lib.Functions.Function1
import rx.subjects.BehaviorSubject
import rx.subjects.PublishSubject
import com.jme3.math.Vector3f
import java.util.List

enum Npc {
	jock,
	nerd,
	kid,
	rabbit
}

enum Bullet {
	dumbbell,
	book,
	candy,
	carrot
}

@Data
class NpcLifeDef {
	Npc kind
	float spawnAt
	int place
	String id
}

class GameData {
	public static val int[][] coeffss = #[
		#[1, 3, 0, 2],
		#[0, 1, 3, 2],
		#[0, 2, 1, 3],
		#[0, 2, 0, 1]
	]

	val ImageRaster[] hitpoints = newArrayOfSize(Npc.values.length)

	def loadData(AssetManager assetManager) {
		for(t : Npc.values) {
			hitpoints.set(t.ordinal, ImageRaster.create(assetManager.loadTexture('''Textures/«t.name».png''').image))
		}
	}

	def pointsFor(Npc npc, Vector2f hitpoint) {
		1
		//pointsFor(hitpoints.get(npc.ordinal), hitpoint)
	}

	static def generator(NpcLifeDef[] npcs, float duration) {
		val index = new AtomicInteger(0)
		return [float progress|
			val b = newLinkedList()
			var i = index.get
			for(; i < npcs.length && npcs.get(i).spawnAt * duration < progress; i++) {
				b.add(npcs.get(i))
			}
			index.set(i)
			b
		]
	}

	static def coeffFor(int[][] coeffss, Npc npc, Bullet bullet) {
		coeffss.get(npc.ordinal).get(bullet.ordinal)
	}

	static def pointsFor(ImageRaster hitpoints, Vector2f point) {
		if (hitpoints == null || point == null) {
			-1
		} else {
			val x = Math.round(hitpoints.width * FastMath.clamp(point.x, 0, 1))
			val y = Math.round(hitpoints.height * FastMath.clamp(point.y, 0, 1))
			println(point + " " + x + " " + y)
			Math.round(hitpoints.getPixel(x, y).r * 10)
		}
	}


	static def generateNpcSeq(int nbPlaces, int nbNpcs, float minInterval, float maxInterval) {
		val prng = new Random()
		val NpcLifeDef[] b = newArrayOfSize(nbNpcs)
		var total = 0f;
		val nbKinds = Npc.values.length
		for(var i = 0; i < nbNpcs; i++) {
			val interval = (prng.nextFloat * (maxInterval - minInterval)) + minInterval
			val ts = total + interval
			val npc = Npc.values.get(prng.nextInt(nbKinds))
			val id = npc.name + ts
			total = ts
			b.set(i, new NpcLifeDef(npc, ts, prng.nextInt(nbPlaces), id))
		}
		val fullTime = total + maxInterval
		b.map[new NpcLifeDef(it.kind, it.spawnAt / fullTime, it.place, it.id)]
	}

	static def quantitiesOfNpcs(NpcLifeDef[] seq) {
		val b = new ArrayList(Npc.values.map[new Pair(it, 0)])
		seq.fold(b)[ acc, v |
			val idx = v.kind.ordinal
			acc.set(idx, new Pair(v.kind, acc.get(idx).value + 1))
			acc
		]
	}

	static def generateBulletSetup(NpcLifeDef[] seq, int[][] coeffss) {
		val b = new ArrayList(Bullet.values.map[new Pair(it, 0)])
		val npcs = quantitiesOfNpcs(seq)
		npcs.map[ t |
			new Pair(t.key, generateSizeOfSplits(countNonZero(coeffss.get(t.key.ordinal)), t.value))
		].fold(b)[ acc, v |
			val npc = v.key
			val splits = v.value
			//System.out.printf("%s\n", new ArrayList(splits))
			for(bullet : Bullet.values) {
				val coeff = coeffss.coeffFor(npc, bullet)
				val qty = splits.get((coeff + splits.size - 1) % splits.size)
				//System.out.printf("%s, %s ,%s\n", coeff, (coeff - 1) % splits.size, qty)
				val idx = bullet.ordinal
				acc.set(idx, new Pair(bullet, acc.get(idx).value + qty))
			}
			acc
		]
	}

	static def countNonZero(int[] a) {
		a.fold(0)[acc, v | acc + (if (v == 0)  0 else 1)]
	}

	static def generateSizeOfSplits(int nbSplit, int total) {
		val prng = new Random()
		val splits = newIntArrayOfSize(4)
		var rest = total
		for(var i = 0; i < (nbSplit - 1); i++) {
			val v = Math.round(prng.nextFloat() * rest)
			rest = rest - v
			splits.set(i, v)
		}
		splits.set(nbSplit - 1, rest)
		//System.out.printf("%s, %s ,%s\n", new ArrayList(splits), total, nbSplit)
		splits.sort.reverse
	}
}

@Data
class Hit {
	String npcId
	Vector2f locOnNpc
	Bullet bullet
}

@Data
class ScoreUpdate {
	int newScore
	int point
	int mult
}

class GameRun {

	val List<NpcLifeDef> npcs
	var now = 0f
	val Function1<Float, LinkedList<NpcLifeDef>> gen
	val ArrayList<Pair<Bullet, Integer>> munitions0
	var bullet0 = Bullet.book
	var score0 = 0

	public val BehaviorSubject<ArrayList<Pair<Bullet, Integer>>> munitions = BehaviorSubject.create()
	public val PublishSubject<NpcLifeDef> npcSpawn = PublishSubject.create()
	public val PublishSubject<NpcLifeDef> npcDespawn = PublishSubject.create()
	public val BehaviorSubject<Bullet> bullet = BehaviorSubject.create()
	public val PublishSubject<Vector2f> reqFire = PublishSubject.create()
	public val PublishSubject<Pair<Bullet, Vector2f>> fire = PublishSubject.create()
	public val PublishSubject<Hit> hits = PublishSubject.create()
	public val BehaviorSubject<ScoreUpdate> scores = BehaviorSubject.create()

	new(GameData gd) {
		npcs = new LinkedList(GameData.generateNpcSeq(3, 30, 0.5f, 2.0f))
		munitions0 = GameData.generateBulletSetup(npcs, GameData.coeffss)
		munitions.onNext(munitions0)
		bullet.onNext(Bullet.book)
		bullet.subscribe[v| bullet0 = v]
		scores.onNext(new ScoreUpdate(score0, 0, 0))
		//System.out.printf("%s == %s \n", npcs.length, munitions.fold(0)[acc, v | acc + v.value])
		gen = GameData.generator(npcs, 60f)
		reqFire.subscribe[v|
			val qty = munitions0.get(bullet0.ordinal).value
			if (qty > 0) {
				munitions0.set(bullet0.ordinal, new Pair(bullet0, qty - 1))
				munitions.onNext(munitions0)
				fire.onNext(new Pair(bullet0, v))
			}
		]
		hits.subscribe[v|
			val npcObj = npcs.findFirst[it.id == v.npcId]
			if (npcObj != null) {
				val mult = GameData.coeffFor(GameData.coeffss, npcObj.kind, v.bullet)
				val point = gd.pointsFor(npcObj.kind, v.locOnNpc)
				score0 = score0 + (point * mult)
				val upt = new ScoreUpdate(score0, point, mult)
				scores.onNext(upt)
				if (mult > 0) {
					npcs.remove(npcObj)
					npcDespawn.onNext(npcObj)
				}
			}
		]
	}

	def updateNpcLife(float tf) {
		now = now + tf
		gen.apply(now).forEach[x | npcSpawn.onNext(x)]
	}

}