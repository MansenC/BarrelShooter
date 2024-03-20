import java.util.ArrayList;
import java.util.List;

/**
 * The cannon class handles control of the cannon. This includes rotating the cannon left/right and up/down.
 * This class also sets the camera position if not in freecam mode according to the cannon's position
 * and handles spawning the cannonballs.
 * Additionally, this also draws the UI overlay if the camera is not in freecam mode.
 *
 * @author HERE_YOUR_FULL_NAME_TODO
 */
public class Cannon
{
  /**
   * The minimum horizontal angle the cannon can shoot at.
   */
  private static final float CANNON_MIN_HORIZONTAL_ANGLE = -45f;
  
  /**
   * The maximum horizontal angle the cannon can shoot at.
   */
  private static final float CANNON_MAX_HORIZONTAL_ANGLE = 45f;
  
  /**
   * The minimum vertical angle the cannon can shoot at.
   */
  private static final float CANNON_MIN_VERTICAL_ANGLE = -5;
  
  /**
   * The maximum vertical angle the cannon can shoot at.
   */
  private static final float CANNON_MAX_VERTICAL_ANGLE = 85;
  
  /**
   * A list of all cannonballs currently shot. Will update every ball in the list,
   * and if the ball died, will remove them from the list.
   */
  private final List<Cannonball> balls = new ArrayList<Cannonball>();
  
  /**
   * The global position of the cannon.
   */
  private final PVector position;
  
  /**
   * The model for the cannon wagon.
   */
  private final PShape cannonWagon;
  
  /**
   * The model for the cannon barrel.
   */
  private final PShape cannon;
  
  /**
   * The model for the cannonballs.
   */
  private final PShape cannonball;
  
  /**
   * The cannon ruler image.
   */
  private final PImage cannonRuler;
  
  /**
   * The icon for the cannon.
   */
  private final PImage cannonIcon;
  
  /**
   * The cannon base image.
   */
  private final PImage cannonBase;
  
  /**
   * The available bomb image.
   */
  private final PImage availableBomb;
  
  /**
   * The used bomb image.
   */
  private final PImage usedBomb;
  
  /**
   * The undamaged ship image.
   */
  private final PImage undamagedShip;
  
  /**
   * The damaged ship image.
   */
  private final PImage damagedShip;
  
  /**
   * The current horizontal rotation of the cannon. In range of [-45..45].
   */
  private float cannonHorizontalRotation = 0;
  
  /**
   * The current vertical rotation of the cannon barrel. Controls how far the balls will shoot.
   * In range of [-15..85].
   */
  private float cannonVerticalRotation = CANNON_MIN_VERTICAL_ANGLE;
  
  /**
   * Constructs a new cannon instance at the provided world position.
   *
   * @param position The position of the cannon.
   */
  public Cannon(PVector position)
  {
    this.position = position;
    cannonWagon = loadShape("CannonWagon.obj");
    cannon = loadShape("Cannon.obj");
    cannonball = loadShape("Cannonball.obj");
    
    cannonRuler = loadImage("game_ruler.png");
    cannonIcon = loadImage("game_cannon.png");
    cannonBase = loadImage("game_cannon_base.png");
    availableBomb = loadImage("game_bomb_available.png");
    usedBomb = loadImage("game_bomb_used.png");
    undamagedShip = loadImage("game_ship_nodamage.png");
    damagedShip = loadImage("game_ship_damage.png");
  }
  
  /**
   * Renders the cannon and UI and updates the parameters according to user input.
   */
  public void update()
  {
    pushMatrix();
    
    // We move our cannon to the given position
    translate(position.x, position.y, position.z);
    rotateX(PI);
    rotateY(radians(cannonHorizontalRotation));
    
    // Only draw the wagon
    shape(cannonWagon);
    
    pushMatrix();
    
    // We need to rotate and translate the cannon so that the metal beam stays fixed in place
    // relative to its wagon.
    float radiansAngle = (cannonVerticalRotation - 90) * PI / 180;
    translate(sin(radiansAngle), 1 - cos(radiansAngle), 0);
    rotateZ(radiansAngle);
    
    // The scope should be on the upper side.
    rotateY(PI);
    shape(cannon);
    
    // If the left mouse button was pressed then we shoot a cannonball.
    // We do this here since we don't have to the transformation for spawning
    // the ball inside the barrel again.
    if (!paused && isMouseButtonPressed(LEFT))
    {
      PVector ballSpawnLocation = new PVector(
        modelX(0, 3, 0),
        modelY(0, 3, 0),
        modelZ(0, 3, 0));
      balls.add(new Cannonball(ballSpawnLocation, cannonHorizontalRotation, cannonVerticalRotation));
    }
    
    popMatrix();
    
    if (!camera.isFreecam())
    {
      handleUserInput();
      
      // Set the camera to a fixed point and rotate it with the cannon.
      camera.setYaw(cannonHorizontalRotation);
      camera.setPitch(25);
      camera.setPosition(
        modelX(-2, 4, 0),
        modelY(-2, 4, 0),
        modelZ(-2, 4, 0));
    }
    
    popMatrix();
    
    // We finally update all cannonballs.
    List<Cannonball> invalidatedBalls = new ArrayList<>();
    for (Cannonball ball : balls)
    {
      ball.update();
      if (ball.isValid())
      {
        continue;
      }
      
      invalidatedBalls.add(ball);
    }
    
    balls.removeAll(invalidatedBalls);
  }
  
  /**
   * Draws the GUI for the cannon game. The GUI includes indicators about how many shots remain,
   * how many barrels have been destroyed and the current angle of the cannon. Will not draw in freecam mode.
   * The GUI uses the camera's {@link Camera#applyGUITransformations} method in order to draw properly.
   */
  public void drawGUI()
  {
    if (camera.isFreecam())
    {
      return;
    }
    
    // We disable depth testing and shading so that we always draw
    // fully lit and on top.
    hint(DISABLE_DEPTH_TEST);
    noLights();
    
    pushMatrix();
    camera.applyGUITransformations();
    
    for (int i = 0; i < 10; i++)
    {
      // Draw the bombs on the left side of the screen so that it takes up half the height,
      // is centered around Y and has a 10% gap to the left.
      drawUIImage(
        availableBomb,
        width / 10f,
        height / 4f + (height / 20f) * i,
        height / 20f,
        height / 20f);
    }
    
    for (int i = 0; i < 5; i++)
    {
      // Draw the ships on the right side of the screen so that it takes up half the height,
      // is centered around Y and has a 10% gap to the right. Ships are 64x48 so their aspect
      // ratio is 4:3, which is why the width is multiplied by that.
      drawUIImage(
        undamagedShip,
        width - (7f / 3f) * height / 10f,
        height / 4f + (height / 10f) * i,
        (4f / 3f) * height / 10f,
        height / 10f);
    }
    
    // We then draw the cannon indicator. This one is aligned so that there's 10% margin
    // to the right of the screen and the same distance to the bottom.
    drawUIImage(
      cannonRuler,
      width - (width / 10f) - (height / 20f),
      height - (width / 10f) - (height / 20f),
      height / 7f,
      height / 7f);
      
    pushMatrix();
    
    // Modify the transformation so we can freely rotate the indicator like the cannon is being rotated.
    translate(
      width - (width / 10f) - (height / 20f) + (2f / 3f) * height / 7f,
      height - (width / 10f) - (height / 20f) + (2f / 3f) * height / 7f,
      0);
    rotateZ(radians(cannonVerticalRotation));
    
    // After that pain, we draw it offset so that the middle right edge is centered on the origin.
    drawUIImage(cannonIcon, -height / 7f, -(1f / 3f) * height / 7f, height / 7f, (2f / 3f) * height / 7f);
    
    popMatrix();
    
    // Finally we draw the cover.
    drawUIImage(
      cannonBase,
      width - (width / 10f) - (height / 20f) + ((1f / 4f) * height / 7f),
      height - (width / 10f) - (height / 20f) + ((1f / 4f) * height / 7f),
      (3f / 4f) * height / 7f,
      (3f / 4f) * height / 7f);
    
    popMatrix();
    hint(ENABLE_DEPTH_TEST);
    environment.restoreLights();
  }
  
  /**
   * Handles the user's input for controlling the cannon. W turns the cannon up, S down,
   * A turns left, D turns right and left click shoots the cannon.
   */
  private void handleUserInput()
  {
    if (isKeyDown('w'))
    {
      cannonVerticalRotation += deltaTime * 10;
    }
    else if (isKeyDown('s'))
    {
      cannonVerticalRotation -= deltaTime * 10;
    }
    
    if (isKeyDown('a'))
    {
      cannonHorizontalRotation -= deltaTime * 10;
    }
    else if (isKeyDown('d'))
    {
      cannonHorizontalRotation += deltaTime * 10;
    }
    
    cannonVerticalRotation = constrain(cannonVerticalRotation, CANNON_MIN_VERTICAL_ANGLE, CANNON_MAX_VERTICAL_ANGLE);
    cannonHorizontalRotation = constrain(cannonHorizontalRotation, CANNON_MIN_HORIZONTAL_ANGLE, CANNON_MAX_HORIZONTAL_ANGLE);
  }
  
  /**
   * Draws a basic image to the UI, given the image to draw, the x and y coordinates and the width/height
   * of the image.
   *
   * @param image The image to display.
   * @param x The top left x coordinate.
   * @param y The top left y coordinate.
   * @param width The targeted width.
   * @param height The targeted height.
   */
  private void drawUIImage(PImage image, float x, float y, float width, float height)
  {
    beginShape();
    texture(image);
    
    // Just a 3D quad width the given parameters.
    vertex(x, y, 0, 0);
    vertex(x + width, y, 1, 0);
    vertex(x + width, y + height, 1, 1);
    vertex(x, y + height, 0, 1);
    
    endShape();
  }
}
