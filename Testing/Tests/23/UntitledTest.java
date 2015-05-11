import org.junit.*;
import static org.junit.Assert.*;

public class UntitledTest {
    



    @Test
    public void testYatzyFail(){
        int expected = 0;
        int[] roll = {1,1,1,1,6};
        int actual = Untitled.calculateYatzy(roll);
        assertEquals(expected, actual);
        roll[0] = 1;
        roll[1] = 1;
        roll[2] = 6;
        roll[3] = 6;
        roll[4] = 6;
        actual = Untitled.calculateYatzy(roll);
        assertEquals(expected, actual);
    }
}