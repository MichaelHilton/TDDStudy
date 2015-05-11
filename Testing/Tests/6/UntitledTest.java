import org.junit.*;
import static org.junit.Assert.*;

public class UntitledTest {
    

    @Test
    public void testChance(){
        int expected = 1+1+3+3+6;
        int[] roll = {1, 1, 3, 3, 6};
        int actual = Untitled.calculateChance(roll);
        assertEquals(expected, actual);
    }
}