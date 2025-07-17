# Action Menu System Workflow

```mermaid
flowchart TD
    A[User Action] --> B{Trigger Type}
    
    B -->|Press leader+a| C[Action Menu]
    B -->|Context Window Auto-show| D[Context Window]
    B -->|Keybind Direct| E[Direct Action]
    
    %% Action Menu Flow
    C --> F[Get current selection state]
    F --> G{Selection State}
    
    G -->|No Selection| H[Cursor Position Menu]
    G -->|Single Selection| I[Single Item Menu]
    G -->|Multiple Selection| J[Multi-Item Menu]
    G -->|Mixed Selection| K[Mixed Item Menu]
    
    %% Cursor Position Menu (No Selection)
    H --> L[Get commit under cursor]
    L --> M{Valid Commit?}
    M -->|No| N[Show error - no commit]
    M -->|Yes| O[Build cursor action menu]
    
    O --> P[Available Actions]
    P --> Q[d - Show diff]
    Q --> R[e - Edit commit]
    R --> S[x - Abandon commit]
    S --> T[s - Squash commit]
    T --> U[S - Split commit]
    U --> V[r - Rebase commit]
    V --> W[D - Duplicate commit]
    W --> X[b - Bookmark operations]
    X --> Y[n - New child change]
    Y --> Z[leader+d - Describe commit]
    
    %% Single Selection Menu
    I --> AA[Get selected item]
    AA --> BB{Item Type}
    BB -->|Commit| CC[Single commit actions]
    BB -->|Bookmark| DD[Single bookmark actions]
    
    CC --> EE[All cursor actions plus:]
    EE --> FF[Context-specific actions]
    FF --> GG[Enhanced descriptions]
    
    DD --> HH[Bookmark-specific actions]
    HH --> II[b - Bookmark operations]
    II --> JJ[s - Squash into bookmark]
    JJ --> KK[Additional bookmark actions]
    
    %% Multiple Selection Menu
    J --> LL[Get selected items]
    LL --> MM{Item Types}
    MM -->|All Commits| NN[Multi-commit actions]
    MM -->|All Bookmarks| OO[Multi-bookmark actions]
    MM -->|Mixed| PP[Mixed selection actions]
    
    NN --> QQ[x - Abandon selected commits]
    QQ --> RR[r - Rebase selected commits]
    RR --> SS[D - Duplicate selected commits]
    SS --> TT[Other multi-commit actions]
    
    %% Mixed Selection Menu
    K --> UU[Handle mixed selection]
    UU --> VV[Separate commits and bookmarks]
    VV --> WW[Show compatible actions]
    WW --> XX[Limited action set]
    
    %% Context Window Auto-show
    D --> YY[Selection change trigger]
    YY --> ZZ[Get current selection]
    ZZ --> AAA{Has Selection?}
    AAA -->|No| BBB[Hide context window]
    AAA -->|Yes| CCC[Show context window]
    
    CCC --> DDD[Position window]
    DDD --> EEE[Update content]
    EEE --> FFF[Show available actions]
    FFF --> GGG[Real-time updates]
    
    %% Action Execution
    Z --> HHH[Action selected]
    GG --> HHH
    KK --> HHH
    TT --> HHH
    XX --> HHH
    
    HHH --> III{Action Type}
    III -->|diff| JJJ[actions.show_diff]
    III -->|edit| KKK[actions.edit_commit]
    III -->|abandon| LLL[actions.abandon_commit]
    III -->|squash| MMM[actions.show_squash_options_menu]
    III -->|split| NNN[actions.show_split_options_menu]
    III -->|rebase| OOO[actions.show_rebase_options_menu]
    III -->|duplicate| PPP[actions.show_duplicate_options_menu]
    III -->|bookmark| QQQ[actions.show_bookmark_menu]
    III -->|new| RRR[actions.new_child]
    III -->|describe| SSS[actions.set_description]
    
    %% Global Actions
    O --> TTT[Add global actions]
    TTT --> UUU[R - Refresh log]
    UUU --> VVV[leader+s - Show status]
    VVV --> WWW[f - Git fetch]
    WWW --> XXX[P - Git push]
    XXX --> YYY[u - Undo last]
    YYY --> ZZZ[c - Commit working copy]
    
    %% Menu Display
    P --> AAAA[Create menu buffer]
    AAAA --> BBBB[Apply menu styling]
    BBBB --> CCCC[Set menu keymaps]
    CCCC --> DDDD[Show menu window]
    DDDD --> EEEE[Focus menu]
    
    %% Menu Navigation
    CCCC --> FFFF[j/k - Navigate items]
    FFFF --> GGGG[Enter - Select action]
    GGGG --> HHHH[q/Escape - Cancel]
    HHHH --> IIII[Number keys - Quick select]
    
    %% Action Validation
    HHH --> JJJJ[Validate action]
    JJJJ --> KKKK{Action Valid?}
    KKKK -->|No| LLLL[Show error - invalid action]
    KKKK -->|Yes| III
    
    %% Error Handling
    N --> MMMM[Return to previous state]
    LLLL --> MMMM
    
    %% Context Window Features
    FFF --> NNNN[Show action descriptions]
    NNNN --> OOOO[Show keybindings]
    OOOO --> PPPP[Show action counts]
    PPPP --> QQQQ[Update position]
    
    %% Menu Styling
    BBBB --> RRRR[Apply action colors]
    RRRR --> SSSS[Highlight shortcuts]
    SSSS --> TTTT[Format descriptions]
    TTTT --> UUUU[Add separators]
    
    %% Dynamic Updates
    GGG --> VVVV[Selection changed]
    VVVV --> WWWW[Update available actions]
    WWWW --> XXXX[Refresh content]
    XXXX --> YYYY[Maintain window position]
    
    %% Styling
    classDef userAction fill:#e1f5fe
    classDef menuAction fill:#f3e5f5
    classDef execution fill:#e8f5e8
    classDef contextWindow fill:#fff3e0
    classDef success fill:#e8f5e8
    classDef error fill:#ffebee
    classDef validation fill:#fff3e0
    
    class A,B,C,D,E userAction
    class F,G,H,I,J,K,O,P,Q,R,S,T,U,V,W,X,Y,Z,AA,BB,CC,DD,EE,FF,GG,HH,II,JJ,KK,LL,MM,NN,OO,PP,QQ,RR,SS,TT,UU,VV,WW,XX,TTT,UUU,VVV,WWW,XXX,YYY,ZZZ menuAction
    class JJJ,KKK,LLL,MMM,NNN,OOO,PPP,QQQ,RRR,SSS,AAAA,BBBB,CCCC,DDDD,EEEE,FFFF,GGGG,HHHH,IIII execution
    class YY,ZZ,AAA,BBB,CCC,DDD,EEE,FFF,GGG,NNNN,OOOO,PPPP,QQQQ,VVVV,WWWW,XXXX,YYYY contextWindow
    class success success
    class N,LLLL,MMMM error
    class M,JJJJ,KKKK validation
```

## Key Components

### Action Menu (`<leader>a`)
- **Context-sensitive**: Shows different actions based on selection state
- **Interactive**: Full menu navigation with keybindings
- **Comprehensive**: Access to all available actions

### Context Window (Auto-show)
- **Non-intrusive**: Automatically appears/disappears with selections
- **Real-time**: Updates content as selections change
- **Informative**: Shows available actions without requiring interaction

## Selection States

### No Selection (Cursor Position)
Actions available for commit under cursor:
- **d**: Show diff
- **e**: Edit commit
- **x**: Abandon commit
- **s**: Squash commit
- **S**: Split commit
- **r**: Rebase commit
- **D**: Duplicate commit
- **b**: Bookmark operations
- **n**: New child change
- **<leader>d**: Describe commit

### Single Selection
- **Commit**: All cursor actions plus enhanced descriptions
- **Bookmark**: Bookmark-specific actions like squash into bookmark

### Multiple Selection
- **Commits**: Multi-commit actions (abandon, rebase, duplicate)
- **Bookmarks**: Bulk bookmark operations
- **Mixed**: Compatible actions for mixed selections

## Global Actions

Available in all contexts:
- **R**: Refresh log
- **<leader>s**: Show status
- **f**: Git fetch
- **P**: Git push
- **u**: Undo last
- **c**: Commit working copy

## Menu Features

- **Navigation**: j/k keys for movement
- **Selection**: Enter to select, q/Escape to cancel
- **Quick Access**: Number keys for direct selection
- **Styling**: Color-coded actions with clear descriptions
- **Validation**: Prevents invalid actions

## Context Window Features

- **Auto-positioning**: Window-relative positioning
- **Dynamic Content**: Real-time updates based on selection
- **Non-focusable**: Stays out of the way during navigation
- **Configurable**: Position and behavior can be customized

## File Locations

- **Action Menu**: `lua/jj-nvim/ui/action_menu.lua`
- **Context Window**: `lua/jj-nvim/ui/context_window.lua`
- **Actions Interface**: `lua/jj-nvim/jj/actions.lua`
- **Window Integration**: `lua/jj-nvim/ui/window.lua`