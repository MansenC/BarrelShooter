import java.util.Set;
import java.util.HashSet;

/**
 * A set of all keys currently being pressed down. Since processing has no clue what key modifiers are,
 * this set only contains the lowercase versions of any character being pressed, so that shift and caps lock
 * have no effect. This is not the case for the respective keyCode, which is required for the modifier keys
 * respectively, namely shift.
 */
Set<Integer> currentlyPressedKeys = new HashSet<>();

/**
 * The keyPressed event so that we do not have to rely on the last key being pressed, which results in unintended
 * behavior really quickly.
 */
void keyPressed()
{
  currentlyPressedKeys.add((int) Character.toLowerCase(key));
  currentlyPressedKeys.add(keyCode);
}

/**
 * The keyReleased event so that we do not have to rely on the last key being pressed, which results in unintended
 * behavior really quickly.
 */
void keyReleased()
{
  currentlyPressedKeys.remove((int) Character.toLowerCase(key));
  currentlyPressedKeys.remove(keyCode);
}

/**
 * This function checks if the given key - character or code - is currently being pressed.
 *
 * @param expectedKey The key code or character to check against.
 * @return True if the key is being pressed down right now, false otherwise.
 */
boolean isKeyDown(int expectedKey)
{
  return currentlyPressedKeys.contains(expectedKey);
}
