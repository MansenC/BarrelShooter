import java.util.ArrayList;
import java.util.List;
import java.util.Random;

PShape barrelShape;

/**
 * Handles the spawning and updating of all barrels in the world.
 */
public class BarrelManager
{
  /**
   * The starting position of barrel spawning. This is the smaller circle of the spawning area.
   */
  private static final float BARREL_SPAWN_X_START = 4_000;
  
  /**
   * The ending position of barrel spawning. This is the larger circle of the spawning area.
   */
  private static final float BARREL_SPAWN_X_END = 9_000;
  
  /**
   * The maximum (and inverted minimum) angle of difference at which barrels can spawn.
   */
  private static final float BARREL_SPAWN_Y_ANGLE = 40f;
  
  /**
   * The minimum distance between two barrels (X/Z).
   */
  private static final float BARREL_MIN_DISTANCE = 400f;
  
  /**
   * The cannon origin describes the center point of the circles that describe the boundary
   * of where barrels can spawn in the water.
   */
  private final PVector cannonOrigin;
  
  /**
   * The list of all barrels that currently are being displayed.
   */
  private final List<Barrel> barrels = new ArrayList<>();
  
  public BarrelManager(PVector origin)
  {
    cannonOrigin = origin;
  }
  
  public void spawnBarrels(int amount)
  {
    // We will spawn barrels randomly around the ocean.
    Random random = new Random();
    while (barrels.size() < amount)
    {
      // We calculate a random angle and distance at which the barrel will be placed.
      float targetYAngle = random.nextFloat(-BARREL_SPAWN_Y_ANGLE, BARREL_SPAWN_Y_ANGLE);
      float targetDistance = random.nextFloat(BARREL_SPAWN_X_START, BARREL_SPAWN_X_END);
      
      PVector targetPosition = new PVector(
        cos(radians(targetYAngle)) * targetDistance,
        0, // For now a fixed Y position, later we'll sample the current wave height
        sin(radians(targetYAngle)) * targetDistance);
      targetPosition.add(cannonOrigin);
      
      // BARREL_MIN_DISTANCE
      // We then check if there's a barrel already close by. If so, we skip this position and try again.
      boolean failedDistanceCheck = false;
      for (Barrel existingBarrel : barrels)
      {
        PVector existingPosition = existingBarrel.getRigidbody().getPosition();
        float distanceX = targetPosition.x - existingPosition.x;
        float distanceZ = targetPosition.z - existingPosition.z;
        
        // We only care about X|Z coordinates, Y doesn't matter here.
        failedDistanceCheck = distanceX * distanceX + distanceZ * distanceZ < BARREL_MIN_DISTANCE * BARREL_MIN_DISTANCE;
        if (failedDistanceCheck)
        {
          break;
        }
      }
      
      if (failedDistanceCheck)
      {
        // We have failed the distance check. Let's try again.
        continue;
      }
      
      // If not then we calculate the current ocean height and adjust the barrel's starting Y position accordingly.
      targetPosition.y = sampleOceanY(targetPosition.x, targetPosition.z);
      barrels.add(new Barrel(targetPosition));
    }
  }
  
  public void update()
  {
    for (Barrel barrel : barrels)
    {
      barrel.draw();
    }
  }
}

/**
 * The barrel class manages the buoyancy simulation part. Barrels can spawn randomly on the ocean
 * and will get affected by the waves, and pushed around. Like everything on a computer, Physics
 * cannot be calculated exactly with such a complex subject, this is why it's an approximation.
 * The calculations on this approximation, however, are exact.
 *
 * Essentially we wrap our barrel in a cylinder and then voxilize this cylinder. We then calculate
 * if said voxel is beneath the water surface based on its center position and then apply force
 * accordingly to the barrel. This will then move and rotate the barrel accordingly.
 */
public class Barrel
{
  private final Rigidbody rigidbody;
  
  public Barrel(PVector position)
  {
    rigidbody = new Rigidbody(barrelShape, position);
  }
  
  public Rigidbody getRigidbody()
  {
    return rigidbody;
  }
  
  public void draw()
  {
    rigidbody.draw();
  }
}
