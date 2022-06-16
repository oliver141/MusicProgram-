import java.lang.System;
import java.util.Properties;
import java.util.concurrent.TimeUnit;
import java.io.*;

import ddf.minim.*;

Properties defaultProps;
Properties props;

PFont font;

String storagePath;

Minim minim;
AudioPlayer[] players;
int playing;

PlayPauseButton play;
PlayBar progress;
DataList list;
Slider volume;
Button importMusic;

boolean flagForReload;
boolean flagForNextSong;
int nextSongFlagged = -1000;

void setup() {
  size(1200, 800);
 
  registerDispose(this);
  storagePath = System.getProperty("user.home") + "/CalsignPlay/";
  (new File(storagePath)).mkdirs();
  try {
    defaultProps = new Properties();
    FileInputStream in = new FileInputStream(storagePath + "defaultProperties.properties");
    defaultProps.load(in);
    in.close();
    props = new Properties(defaultProps);
    in = new FileInputStream(storagePath + "properties.properties");
    props.load(in);
    in.close();
  } catch(Exception e) {
    System.err.println("Could not load the properties files. Attempting to create them now...");
    e.printStackTrace();
    defaultProps = new Properties();
    defaultProps.setProperty("volume", str(50));
   
    props = new Properties(defaultProps);
   
    try {
      FileOutputStream out = new FileOutputStream(storagePath + "defaultProperties.properties");
      defaultProps.store(out, "---No Comment---");
      out.close();
     
      out = new FileOutputStream(storagePath + "properties.properties");
      props.store(out, "---No Comment---");
      out.close();
    } catch(Exception f) {
      System.err.println("Unable to create properties files!");
      f.printStackTrace();
    }
  }
 
  font = createFont("Arial", 12);
  textFont(font);
  minim = new Minim(this);
  list = new DataList(20, 90, width - 40, height - 150) {
    public void selected(int id) {
      players[playing].pause();
      players[playing].rewind();
      playing = id;
      players[playing].play();
    }
  };
  reload();
  play = new PlayPauseButton(20, 20, 60, 50) {
    public void action() {
      if (players[playing].isPlaying())
        players[playing].pause();
      else
        players[playing].play();
    }
    public boolean isPlaying() {
      if(players.length > 0)
        return players[playing].isPlaying();
      else
        return false;
    }
  };
  progress = new PlayBar(80, 43, width - 280, 18) {
    public void updateProgress(float skip) {
      if(players.length > 0)
        players[playing].skip((int) map(skip, 0, 100, 0, players[playing].length()) - players[playing].position());
    }
    public float getComplete() {
      if(players.length > 0)
        return map(players[playing].position(), 0, players[playing].length(), 0, 100);
      else
        return 0;
    }
  };
  volume = new Slider(width - 180, 43, 160, 18) {
    public void updateValue(float value) {
      for (AudioPlayer player : players)
        player.setGain(map(value, 0, 100, -40, 5));
    }
    public float getValue() {
      if(players.length > 0)
        return map(players[playing].getGain(), -40, 5, 0, 100);
      else
        return map(int(props.getProperty("volume")), 0, 100, -40, 5);
    }
  };
  importMusic = new Button(20, height - 40, 60, 20) {
    public void display() {
      stroke(0);
      if (over())
        fill(204);
      else
        fill(250);
      rect(loc.x, loc.y, dim.x, dim.y);
      textSize(12);
      textAlign(CENTER, CENTER);
      fill(0);
      text("Import...", loc.x + dim.x / 2, loc.y + dim.y / 2);
    }
    public void action() {
      selectInput("Select file or folder to import", "importMusic");
    }
  };
 
  float gain = map(int(props.getProperty("volume")), 0, 100, -40, 5);
 
  for(AudioPlayer player : players)
    player.setGain(gain);
  smooth();
}

void draw() {
  background(255);
 
  if(flagForReload) {
    reload();
    flagForReload = false;
  }
 
  if(!flagForNextSong && players.length > 0 && players[playing].position() >= players[playing].length() - 1000) {
    flagForNextSong = true;
    nextSongFlagged = millis() + (players[playing].position() - players[playing].length() - 1000);
  }
 
  if(flagForNextSong && millis() - nextSongFlagged >= 1000) {
    players[playing].pause();
    players[playing].rewind();
   
    if(playing < players.length - 1) {
      playing ++;
      players[playing].play();
    }
   
    flagForNextSong = false;
    nextSongFlagged = -1000;
  }
  progress.display();
  play.display();
 
  if(players.length > 0) {
    AudioMetaData metadata = players[playing].getMetaData();
   
    fill(0);
    textSize(12);
    textAlign(LEFT, BOTTOM);
   
    text(metadata.title() + "  -  " + metadata.album() + "  -  " + metadata.author(), 90, 38);
   
    textAlign(RIGHT, BOTTOM);
   
    long pos = players[playing].position();
   
    String position = String.format("%d:%02d",
      TimeUnit.MILLISECONDS.toMinutes(pos),
      TimeUnit.MILLISECONDS.toSeconds(pos) -
      TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS.toMinutes(pos))
    );
   
    long len = players[playing].length();
   
    String length = String.format("%d:%02d",
      TimeUnit.MILLISECONDS.toMinutes(len),
      TimeUnit.MILLISECONDS.toSeconds(len) -
      TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS.toMinutes(len))
    );
   
    text(position + "  /  " + length, width - 200, 38);
  }
 
  list.display();
  volume.display();
  importMusic.display();
}

void mousePressed() {
  play.update();
  progress.update();
  list.update();
  volume.update();
  importMusic.update();
}

void mouseDragged() {
  volume.updateDrag();
}

void mouseReleased() {
  volume.updateRelease();
}

void importMusic(File selection) {
  String toImport = selection.getAbsolutePath();

  try {
    FileWriter writer = new FileWriter(new File(storagePath + "songs.txt"), true);
    writer.write(System.getProperty("line.separator") + toImport);
    writer.flush();
    writer.close();
  }
  catch(IOException e) {
    e.printStackTrace();
  }
  flagForReload = true;
}

void reload() {
  players = new AudioPlayer[0];

 
  File songsDest = new File(storagePath + "songs.txt");
 
  if(!songsDest.exists()) {
    String[] lines = {};
    saveStrings(songsDest.getAbsolutePath(), lines);
  }
 
  String[] songs = new String[0];
  BufferedReader reader = createReader(storagePath + "songs.txt");
  String line = "";
  while (line != null) {
    try {
      line = reader.readLine();
      if (line != null) songs = append(songs, line);
    }
    catch (IOException e) {
      e.printStackTrace();
      line = null;
    }
  }
  try {
    reader.close();
  }
  catch(IOException e) {
    e.printStackTrace();
  }
  list.items.clear();
  for (String path : songs) {
    try {
      AudioPlayer temp = minim.loadFile(path);
      AudioMetaData metadata = temp.getMetaData();
     
      String[] data = {
        metadata.title(), metadata.album(), metadata.author(), metadata.genre()
      };
     
      list.addItem(data);
     
      players = (AudioPlayer[]) append(players, temp);
    } catch(Exception e) {
      System.err.println("Unable to load song: " + path);
      e.printStackTrace();
    }
  }
}

void dispose() {
  props.setProperty("volume", str(map(players[playing].getGain(), -40, 5, 0, 100)));
 
  try {
    FileOutputStream out = new FileOutputStream(storagePath + "properties.properties");
    props.store(out, "---No Comment---");
    out.close();
  } catch(Exception e) {
    e.printStackTrace();
  }
}

abstract class Button {
  PVector loc;
  PVector dim;
 
  Button(float x, float y, float w, float h) {
    loc = new PVector(x, y);
    dim = new PVector(w, h);
  }
 
  boolean over() {
    return (mouseX > loc.x && mouseX < loc.x + dim.x && mouseY > loc.y && mouseY < loc.y + dim.y);
  }
 
  void update() {
    if(mousePressed && over())
     action();
  }
 
  abstract void display();
  abstract void action();
}
abstract class DataList {
  ArrayList<ListItem> items;
 
  PVector loc;
  PVector dim;
 
  DataList(float x, float y, float w, float h) {
    items = new ArrayList<ListItem>();
   
    loc = new PVector(x, y);
    dim = new PVector(w, h);
  }
 
  void addItem(String[] data) {
    items.add(new ListItem(data, items.size()));
  }
 
  void update() {
    if(mousePressed && mouseX > loc.x && mouseX < loc.x + dim.x && mouseY > loc.y && mouseY < loc.y + dim.y) {
      int over = (int) (mouseY - (loc.y + 5)) / 20;
      if(over > -1 && over < items.size())
        selected(over);
    }
  }
 
  void display() {
    strokeWeight(1);
    stroke(0);
    fill(250);
   
    rect(loc.x, loc.y, dim.x, dim.y);
   
    textSize(12);
    textAlign(LEFT, TOP);
    noStroke();
   
    float down = 0;
    boolean dark = false;
    for(ListItem item : items) {
      if(dark)
        fill(204);
      else
        fill(250);
      rect(loc.x + 1, loc.y + 1 + down, dim.x - 1, 20 - 1);
     
      fill(0);
     
      float over = 0;
      for(String data : item.data) {
        if(textWidth(data + "...") > ((dim.x - 10) / item.data.length) - 5) {
          while(textWidth(data + "...") > ((dim.x - 10) / item.data.length) - 5) {
            data = data.substring(0, data.length() - 1);
          }
         
          data += "...";
        }
       
        text(data, loc.x + 5 + over, loc.y + 3 + down);
       
        over += (dim.x - 10) / item.data.length;
      }
     
      down += 20;
      dark = !dark;
    }
   
  
   
    if(dark)
      fill(204);
    else
      fill(250);
   
    rect(loc.x + 1, loc.y + 1 + down, dim.x - 1, dim.y - (down + 1));
  }
 
  abstract void selected(int id);
}
class ListItem {
  int id;
  String[] data;
 
  ListItem(String[] data, int id) {
    this.id = id;
    this.data = data;
  }
}

abstract class PlayBar {
  PVector loc;
  PVector dim;
 
  PlayBar(float x, float y, float w, float h) {
    loc = new PVector(x, y);
    dim = new PVector(w, h);
  }
 
  void update() {
    if(mousePressed && over())
      updateProgress(map(mouseX - loc.x, 0, dim.x, 0, 100));
  }
 
  void display() {
    strokeWeight(1);
    stroke(0);
    fill(250);
   
    rect(loc.x, loc.y, dim.x, dim.y);
   
    fill(0);
   
    rect(loc.x, loc.y, map(getComplete(), 0, 100, 0, dim.x), dim.y);
  }
 
  boolean over() {
    return (mouseX > loc.x && mouseX < loc.x + dim.x && mouseY > loc.y && mouseY < loc.y + dim.y);
  }
 
  abstract void updateProgress(float skip);
  abstract float getComplete();
}
abstract class PlayPauseButton extends Button {
  PlayPauseButton(float x, float y, float w, float h) {
    super(x, y, w, h);
  }
 
  void display() {
    strokeWeight(2);
    stroke(0);
    if(!over())
      fill(255);
    else
      fill(0);
   
    rect(loc.x, loc.y, dim.x, dim.y);
   
    noStroke();
    if(!over())
      fill(0);
    else
     fill(255);
   
    if(!isPlaying()) {
      triangle(loc.x + dim.x / 4, loc.y + dim.y / 4, loc.x + dim.x / 4, loc.y + dim.y / 4 * 3, loc.x + dim.x / 4 * 3, loc.y + dim.y / 2);
    } else {
      rect(loc.x + dim.x / 8 * 2, loc.y + dim.y / 4, dim.x / 5, dim.y / 2);
      rect(loc.x + dim.x / 8 * 6, loc.y + dim.y / 4, -dim.x / 5, dim.y / 2);
    }
  }
 
  abstract boolean isPlaying();
}

abstract class Slider {
  PVector loc;
  PVector dim;
 
  boolean dragging;
 
  Slider(float x, float y, float w, float h) {
    loc = new PVector(x, y);
    dim = new PVector(w, h);
  }
 
  void update() {
    if(mousePressed && over()) {
      updateValue(constrain(map(mouseX - loc.x, 0, dim.x, 0, 100), 0, 100));
      dragging = true;
    }
  }
 
  void updateDrag() {
    if(mousePressed && dragging)
      updateValue(constrain(map(mouseX - loc.x, 0, dim.x, 0, 100), 0, 100));
  }
 
  void updateRelease() {
    dragging = false;
  }
 
  void display() {
    strokeWeight(1);
    stroke(0);
    fill(250);
   
    rect(loc.x, loc.y, dim.x, dim.y);
   
    fill(0);
   
    rect(loc.x, loc.y, map(getValue(), 0, 100, 0, dim.x), dim.y);
  }
 
  boolean over() {
    return (mouseX > loc.x && mouseX < loc.x + dim.x && mouseY > loc.y && mouseY < loc.y + dim.y);
  }
 
  abstract void updateValue(float value);
  abstract float getValue();
}
