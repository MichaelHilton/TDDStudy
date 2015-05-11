
public class Untitled {
    
    public static int answer() {
        return 6*9;
    }

    public static int calculateChance(int[] roll){
        int result = roll[0];
        result += roll [1];
        result += roll [2];
        result += roll [3];
        result += roll [4];
        return result;
    }

    public static int calculateYatzy(int[] roll){
        if(roll[0] == roll[1] && roll[2] == roll[3] && roll[3]==roll[4]){
            return 50;
        }
        return 0;
    }
}