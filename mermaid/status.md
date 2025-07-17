# Status Command Workflow

```mermaid
flowchart TD
    A[User Action] --> B{Action Type}
    
    B -->|Press leader+s| C[Status Command]
    B -->|leader+a action menu| D[Action Menu]
    
    %% Status Command Flow
    C --> E[show_status]
    E --> F[Build jj status command]
    F --> G[jj status]
    
    %% Action Menu Flow
    D --> H{Menu Selection}
    H -->|Global Action| I[Show status leader+s]
    I --> E
    
    %% Execute Status Command
    G --> J[commands.execute_with_immutable_prompt]
    J --> K[Execute jj command]
    K --> L{Success?}
    
    L -->|Yes| M[Parse status output]
    L -->|No| N[Show error message]
    
    %% Success Path - Create Status Buffer
    M --> O[Create status buffer]
    O --> P[Set buffer options]
    P --> Q[buftype=nofile]
    Q --> R[modifiable=false]
    R --> S[filetype=jj-status]
    
    %% Apply Status Syntax Highlighting
    S --> T[Apply syntax highlighting]
    T --> U{Status Elements}
    
    U -->|Working Copy| V[Highlight working copy changes]
    U -->|Conflicts| W[Highlight conflicts]
    U -->|Untracked Files| X[Highlight untracked files]
    U -->|Staged Changes| Y[Highlight staged changes]
    U -->|Bookmarks| Z[Highlight bookmark info]
    
    V --> AA[Apply working copy colors]
    W --> BB[Apply conflict colors]
    X --> CC[Apply untracked colors]
    Y --> DD[Apply staged colors]
    Z --> EE[Apply bookmark colors]
    
    %% Display Status Buffer
    AA --> FF[Display status buffer]
    BB --> FF
    CC --> FF
    DD --> FF
    EE --> FF
    
    FF --> GG[Set buffer keymaps]
    GG --> HH[Show status window]
    HH --> II[Set window options]
    II --> JJ[Focus status window]
    
    %% Buffer Configuration
    P --> KK[Set buffer properties]
    KK --> LL[Set buffer name]
    LL --> MM[Configure buffer local settings]
    
    %% Window Configuration
    II --> NN[Set window properties]
    NN --> OO[Split window appropriately]
    OO --> PP[Resize window]
    PP --> QQ[Position window]
    
    %% Status Buffer Keymaps
    GG --> RR[Set status buffer keymaps]
    RR --> SS[q - close status]
    SS --> TT[r - refresh status]
    TT --> UU[Enter - go to file]
    UU --> VV[Other navigation keys]
    
    %% Refresh Functionality
    TT --> WW[Refresh trigger]
    WW --> XX[Re-execute status command]
    XX --> E
    
    %% Status Information Display
    M --> YY[Parse status sections]
    YY --> ZZ{Status Sections}
    
    ZZ -->|Working Copy| AAA[Show working copy status]
    ZZ -->|Current Commit| BBB[Show current commit info]
    ZZ -->|Parent Commits| CCC[Show parent information]
    ZZ -->|Bookmarks| DDD[Show bookmark status]
    ZZ -->|Conflicts| EEE[Show conflict information]
    
    AAA --> FFF[Format working copy display]
    BBB --> GGG[Format commit display]
    CCC --> HHH[Format parent display]
    DDD --> III[Format bookmark display]
    EEE --> JJJ[Format conflict display]
    
    FFF --> O
    GGG --> O
    HHH --> O
    III --> O
    JJJ --> O
    
    %% Error Handling
    N --> KKK[Return to previous state]
    
    %% Context Integration
    JJ --> LLL[Update context]
    LLL --> MMM[Show repository status]
    MMM --> NNN[Display file changes]
    NNN --> OOO[Show conflict markers]
    
    %% Styling
    classDef userAction fill:#e1f5fe
    classDef execution fill:#e8f5e8
    classDef buffer fill:#f3e5f5
    classDef syntax fill:#fff3e0
    classDef success fill:#e8f5e8
    classDef error fill:#ffebee
    
    class A,B,C,D userAction
    class E,F,G,J,K,XX execution
    class O,P,Q,R,S,GG,HH,II,JJ,KK,LL,MM,NN,OO,PP,QQ,RR,SS,TT,UU,VV buffer
    class T,U,V,W,X,Y,Z,AA,BB,CC,DD,EE,FF syntax
    class M,YY,ZZ,AAA,BBB,CCC,DDD,EEE,FFF,GGG,HHH,III,JJJ,LLL,MMM,NNN,OOO success
    class N,KKK error
```

## Key Features

- **Repository Status**: Shows current working copy state
- **Syntax Highlighting**: Color-coded status elements
- **Interactive Buffer**: Keymaps for navigation and refresh
- **Comprehensive Info**: Working copy, commits, bookmarks, conflicts

## Status Information

The status command displays:
- **Working Copy**: Current changes and state
- **Current Commit**: Active commit information
- **Parent Commits**: Commit hierarchy
- **Bookmarks**: Local and remote bookmark status
- **Conflicts**: Any merge conflicts present
- **Untracked Files**: Files not in version control

## Buffer Features

- **Read-only**: Status buffer is not modifiable
- **Syntax Highlighting**: Appropriate colors for each status element
- **Keymaps**: 
  - `q` - close status buffer
  - `r` - refresh status
  - `Enter` - go to file under cursor
  - Navigation keys for movement
- **Auto-refresh**: Can be refreshed without reopening

## Status Elements Highlighting

- **Working Copy Changes**: Modified files and their status
- **Conflicts**: Merge conflicts with special highlighting
- **Untracked Files**: Files not tracked by jj
- **Staged Changes**: Changes ready for commit
- **Bookmarks**: Local and remote bookmark information

## File Locations

- **Core**: `lua/jj-nvim/jj/status.lua`
- **Actions**: `lua/jj-nvim/jj/actions.lua:561-562`
- **Action Menu**: `lua/jj-nvim/ui/action_menu.lua:172-176`
- **Keybinding**: `<leader>s` for status command