import java.util.Set;
import java.util.HashSet;

/**
 * A set of all keys currently being pressed down. Since processing has no clue what key modifiers are,
 * this set only contains the lowercase versions of any character being pressed, so that shift and caps lock
 * have no effect. This is not the case for the respective keyCode, which is required for the modifier keys
 * respectively, namely shift.
 */
private static Set<Integer> currentlyPressedKeys = new HashSet<>();

/**
 * A set of all keys that were pressed down this frame. Acts identically to {@link #currentlyPressedKeys}.
 */
private static Set<Integer> framePressedKeys = new HashSet<>();

/**
 * A set of all mouse buttons that were pressed down this frame.
 */
private static Set<Integer> framePressedMouseButtons = new HashSet<>();

/**
 * The keyPressed event listens so that we do not have to rely on the last key being pressed, which results in unintended
 * behavior really quickly.
 */
void keyPressed()
{
  currentlyPressedKeys.add((int) Character.toLowerCase(key));
  currentlyPressedKeys.add(keyCode);
  framePressedKeys.add((int) Character.toLowerCase(key));
  framePressedKeys.add(keyCode);
}

/**
 * The keyReleased event listens so that we do not have to rely on the last key being pressed, which results in unintended
 * behavior really quickly.
 */
void keyReleased()
{
  currentlyPressedKeys.remove((int) Character.toLowerCase(key));
  currentlyPressedKeys.remove(keyCode);
}

/**
 * The mousePressed event listens so that any mouse button currently pressed gets registered.
 */
void mousePressed()
{
  framePressedMouseButtons.add(mouseButton);
}

/**
 * This function checks if the given key - character or code - is currently being pressed.
 *
 * @param expectedKey The key code or character to check against.
 * @return True if the key is being pressed down right now, false otherwise.
 */
private static boolean isKeyDown(int expectedKey)
{
  return currentlyPressedKeys.contains(expectedKey);
}

/**
 * This function checks if the given key - character or code - was pressed down this frame.
 *
 * @param expectedKey The key code or character to check against.
 * @return True if the key was pressed down this frame, false otherwise.
 */
private static boolean isKeyPressed(int expectedKey)
{
  return framePressedKeys.contains(expectedKey);
}

/**
 * This function checks if a given key combination was pressed this frame. A combination consists of two
 * keys in this case, most likely a modifier key like shift or control, and a regular key, like Ctrl+F.
 *
 * @param modifier The modifier for the combination.
 * @param expectedKey The key code or character to check against.
 * @return True if the key combination was entered this frame, false otherwise.
 */
private static boolean isCombinationPressed(int modifier, int expectedKey)
{
  if (!isKeyDown(modifier) || !isKeyDown(expectedKey))
  {
    return false;
  }
  
  return isKeyPressed(modifier) || isKeyPressed(expectedKey);
}

/**
 * This function checks if the given mouse button was pressed down this frame.
 *
 * @param expectedButton The button to check against.
 * @return True if the mouse button was pressed down this frame, false otherwise.
 */
private static boolean isMouseButtonPressed(int expectedButton)
{
  return framePressedMouseButtons.contains(expectedButton);
}
