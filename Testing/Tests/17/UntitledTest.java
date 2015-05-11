import org.junit.*;
import static org.junit.Assert.*;

public class UntitledTest {
    



    @Test
    public void testYatzy2(){
        int expected = 0;
        int[] roll = {1,1,1,1,6};
        int actual = Untitled.calculateYatzy(roll);
        assertEquals(expected, actual);
    }
}