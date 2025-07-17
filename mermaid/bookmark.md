# Bookmark Operations Workflow

```mermaid
flowchart TD
    A[User Action] --> B{Action Type}
    
    B -->|Press b on commit| C[Bookmark Menu]
    B -->|leader+a action menu| D[Action Menu]
    B -->|View toggle Tab/Ctrl+T| E[Bookmark View Toggle]
    
    %% Bookmark Menu Flow
    C --> F[Show bookmark menu]
    F --> G{Select Operation}
    
    G -->|c| H[Create bookmark]
    G -->|d| I[Delete bookmark]
    G -->|f| J[Forget bookmark]
    G -->|m| K[Move bookmark]
    G -->|r| L[Rename bookmark]
    G -->|s| M[Set bookmark]
    G -->|t| N[Track bookmark]
    G -->|u| O[Untrack bookmark]
    G -->|p| P[Push bookmark]
    
    %% Create Bookmark
    H --> Q[Prompt for bookmark name]
    Q --> R{Name Provided?}
    R -->|No| S[Cancel operation]
    R -->|Yes| T[create_bookmark]
    T --> U[Get commit under cursor]
    U --> V[Build jj bookmark create command]
    V --> W[jj bookmark create bookmark_name -r change_id]
    
    %% Delete Bookmark
    I --> X[Show bookmark selection menu]
    X --> Y[Select bookmark to delete]
    Y --> Z[delete_bookmark]
    Z --> AA[Build jj bookmark delete command]
    AA --> BB[jj bookmark delete bookmark_name]
    
    %% Forget Bookmark
    J --> CC[Show bookmark selection menu]
    CC --> DD[Select bookmark to forget]
    DD --> EE[forget_bookmark]
    EE --> FF[Build jj bookmark forget command]
    FF --> GG[jj bookmark forget bookmark_name]
    
    %% Move Bookmark
    K --> HH[Show bookmark selection menu]
    HH --> II[Select bookmark to move]
    II --> JJ[Enter target selection mode]
    JJ --> KK[Select target commit]
    KK --> LL[move_bookmark]
    LL --> MM[Build jj bookmark move command]
    MM --> NN[jj bookmark move bookmark_name -r target_change_id]
    
    %% Rename Bookmark
    L --> OO[Show bookmark selection menu]
    OO --> PP[Select bookmark to rename]
    PP --> QQ[Prompt for new name]
    QQ --> RR{New Name Provided?}
    RR -->|No| S
    RR -->|Yes| SS[rename_bookmark]
    SS --> TT[Build jj bookmark rename command]
    TT --> UU[jj bookmark rename old_name new_name]
    
    %% Set Bookmark
    M --> VV[Show bookmark selection menu]
    VV --> WW[Select bookmark to set]
    WW --> XX[Enter target selection mode]
    XX --> YY[Select target commit]
    YY --> ZZ[set_bookmark]
    ZZ --> AAA[Build jj bookmark set command]
    AAA --> BBB[jj bookmark set bookmark_name -r target_change_id]
    
    %% Track Bookmark
    N --> CCC[Show remote bookmark menu]
    CCC --> DDD[Select remote bookmark]
    DDD --> EEE[track_bookmark]
    EEE --> FFF[Build jj bookmark track command]
    FFF --> GGG[jj bookmark track bookmark_name@remote]
    
    %% Untrack Bookmark
    O --> HHH[Show tracked bookmark menu]
    HHH --> III[Select bookmark to untrack]
    III --> JJJ[untrack_bookmark]
    JJJ --> KKK[Build jj bookmark untrack command]
    KKK --> LLL[jj bookmark untrack bookmark_name@remote]
    
    %% Push Bookmark
    P --> MMM[Show local bookmark menu]
    MMM --> NNN[Select bookmark to push]
    NNN --> OOO[push_bookmark]
    OOO --> PPP[Build jj bookmark push command]
    PPP --> QQQ[jj bookmark push bookmark_name]
    
    %% Action Menu Flow
    D --> RRR{Menu Selection}
    RRR -->|Single Selection| SSS[Bookmark operations b]
    SSS --> F
    
    %% Bookmark View Toggle
    E --> TTT[Toggle to bookmark view]
    TTT --> UUU[get_all_bookmarks]
    UUU --> VVV[Display bookmark list]
    VVV --> WWW[Enable bookmark navigation]
    WWW --> XXX[Bookmark-specific actions]
    
    %% Common Execution Path
    W --> YYY[commands.execute_with_immutable_prompt]
    BB --> YYY
    GG --> YYY
    NN --> YYY
    UU --> YYY
    BBB --> YYY
    GGG --> YYY
    LLL --> YYY
    QQQ --> YYY
    
    YYY --> ZZZ[Execute jj command]
    ZZZ --> AAAA{Success?}
    
    AAAA -->|Yes| BBBB[Show success notification]
    AAAA -->|No| CCCC[Show error message]
    
    %% Success Path
    BBBB --> DDDD[Refresh log display]
    DDDD --> EEEE[Update bookmark display]
    EEEE --> FFFF[Show operation result]
    
    %% Smart Push Handling
    QQQ --> GGGG{Push Error?}
    GGGG -->|Bookmark Error| HHHH[Parse error message]
    GGGG -->|Other Error| CCCC
    GGGG -->|Success| BBBB
    
    HHHH --> IIII{New Bookmark?}
    IIII -->|Yes| JJJJ[Show retry dialog]
    IIII -->|No| CCCC
    
    JJJJ --> KKKK{User Confirms?}
    KKKK -->|Yes| LLLL[Retry with --allow-new]
    KKKK -->|No| MMMM[Cancel operation]
    
    LLLL --> NNNN[jj bookmark push --allow-new bookmark_name]
    NNNN --> OOOO[Handle retry result]
    
    %% Bookmark Data Management
    UUU --> PPPP[Parse bookmark data]
    PPPP --> QQQQ[Filter present bookmarks]
    QQQQ --> RRRR[Format for display]
    RRRR --> SSSS[Apply bookmark colors]
    
    %% Error Handling
    CCCC --> TTTT[Return to previous state]
    S --> TTTT
    MMMM --> TTTT
    
    %% Validation
    T --> UUUU{Valid Commit?}
    UUUU -->|No| VVVV[Show error - invalid commit]
    UUUU -->|Yes| V
    VVVV --> TTTT
    
    %% Styling
    classDef userAction fill:#e1f5fe
    classDef menuAction fill:#f3e5f5
    classDef execution fill:#e8f5e8
    classDef command fill:#fff3e0
    classDef success fill:#e8f5e8
    classDef error fill:#ffebee
    classDef bookmark fill:#f3e5f5
    classDef smart fill:#e1f5fe
    
    class A,B,C,D,E userAction
    class F,G,Q,R,X,Y,CC,DD,HH,II,JJ,KK,OO,PP,QQ,RR,VV,WW,XX,YY,CCC,DDD,HHH,III,MMM,NNN,RRR,SSS menuAction
    class T,Z,EE,LL,SS,ZZ,EEE,JJJ,OOO,V,AA,FF,MM,TT,AAA,FFF,KKK,PPP,YYY,ZZZ execution
    class W,BB,GG,NN,UU,BBB,GGG,LLL,QQQ command
    class BBBB,DDDD,EEEE,FFFF success
    class CCCC,TTTT,VVVV error
    class UUU,VVV,WWW,XXX,PPPP,QQQQ,RRRR,SSSS bookmark
    class HHHH,IIII,JJJJ,KKKK,LLLL,NNNN,OOOO smart
```

## Key Menu Options

- **c**: Create bookmark at current commit
- **d**: Delete existing bookmark
- **f**: Forget bookmark (remove without propagating deletion)
- **m**: Move bookmark to different commit
- **r**: Rename bookmark
- **s**: Set bookmark to point to specific commit
- **t**: Track remote bookmark
- **u**: Untrack remote bookmark
- **p**: Push bookmark to remote

## Command Variations

- **Create**: `jj bookmark create <name> -r <change_id>`
- **Delete**: `jj bookmark delete <name>`
- **Forget**: `jj bookmark forget <name>`
- **Move**: `jj bookmark move <name> -r <target_change_id>`
- **Rename**: `jj bookmark rename <old_name> <new_name>`
- **Set**: `jj bookmark set <name> -r <target_change_id>`
- **Track**: `jj bookmark track <name@remote>`
- **Untrack**: `jj bookmark untrack <name@remote>`
- **Push**: `jj bookmark push <name>`

## Advanced Features

- **Bookmark View**: Toggle between commit log and bookmark list views
- **Smart Push**: Automatic retry with `--allow-new` for new bookmarks
- **Filtering**: Separate menus for local, remote, and tracked bookmarks
- **Visual Integration**: Bookmarks displayed with consistent colors in log view

## File Locations

- **Core**: `lua/jj-nvim/jj/bookmark_commands.lua`
- **Actions**: `lua/jj-nvim/jj/actions.lua:546-560`
- **Action Menu**: `lua/jj-nvim/ui/action_menu.lua:144-148`
- **View Toggle**: `lua/jj-nvim/ui/window.lua` (Ctrl+T/Tab)
- **Keybinding**: `b` key for bookmark menu