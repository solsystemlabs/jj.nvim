# Squash Command Workflow

```mermaid
flowchart TD
    A[User Action] --> B{Action Type}
    
    B -->|Press s on commit| C[Single Commit Squash]
    B -->|leader+a action menu| D[Action Menu]
    B -->|Command Flow Interface| E[Command Flow]
    
    %% Single Commit Squash Flow
    C --> F[show_squash_options_menu]
    F --> G[Squash Options Menu]
    G --> H{Select Option}
    
    H -->|q| I[Quick squash into parent]
    H -->|i| J[Interactive squash]
    H -->|c| K[Custom destination]
    H -->|f| L[From source commit]
    H -->|b| M[Into bookmark]
    
    %% Quick Squash (into parent)
    I --> N[squash_into_commit parent]
    N --> O[Build jj squash command]
    O --> P[jj squash --into parent_change_id]
    
    %% Interactive Squash
    J --> Q[Enter target selection mode]
    Q --> R[Interactive target selection]
    R --> S[squash_into_commit target]
    S --> T[Build jj squash --interactive]
    T --> U[jj squash --interactive --into target_change_id]
    
    %% Custom Destination
    K --> V[Enter target selection mode]
    V --> W[Interactive target selection]
    W --> X[squash_into_commit target]
    X --> Y[Build jj squash command]
    Y --> Z[jj squash --into target_change_id]
    
    %% From Source
    L --> AA[Enter source selection mode]
    AA --> BB[Select source commit]
    BB --> CC[Enter target selection mode]
    CC --> DD[Select target commit]
    DD --> EE[Build jj squash --from source]
    EE --> FF[jj squash --from source_change_id --into target_change_id]
    
    %% Into Bookmark
    M --> GG[Enter bookmark selection mode]
    GG --> HH[Select bookmark target]
    HH --> II[squash_into_bookmark]
    II --> JJ[Build jj squash command]
    JJ --> KK[jj squash --into bookmark_name]
    
    %% Action Menu Flow
    D --> LL{Menu Selection}
    LL -->|Single Selection| MM[Squash commit s]
    MM --> F
    
    %% Command Flow Interface
    E --> NN[Step 1: Target Selection Type]
    NN --> OO[Step 2: Interactive Target Selection]
    OO --> PP[Step 3: Flag Menu]
    PP --> QQ[execute_command]
    
    %% Common Execution Path
    P --> RR[commands.execute_with_immutable_prompt]
    U --> RR
    Z --> RR
    FF --> RR
    KK --> RR
    QQ --> RR
    
    RR --> SS[Execute jj command]
    SS --> TT{Success?}
    
    TT -->|Yes| UU[Show success notification]
    TT -->|No| VV[Show error message]
    
    %% Success Path
    UU --> WW[Refresh log display]
    WW --> XX[Update commit graph]
    
    %% Error Handling
    VV --> YY[Return to previous state]
    
    %% Validation
    N --> ZZ{Root Commit?}
    S --> ZZ
    X --> ZZ
    ZZ -->|Yes| AAA[Show error - cannot squash root]
    ZZ -->|No| O
    AAA --> YY
    
    %% Styling
    classDef userAction fill:#e1f5fe
    classDef menuAction fill:#f3e5f5
    classDef execution fill:#e8f5e8
    classDef command fill:#fff3e0
    classDef success fill:#e8f5e8
    classDef error fill:#ffebee
    
    class A,B,C,D,E userAction
    class F,G,H,Q,R,V,W,AA,BB,CC,DD,GG,HH,LL,MM,NN,OO,PP menuAction
    class N,S,X,II,O,T,Y,EE,JJ,QQ,RR,SS execution
    class P,U,Z,FF,KK command
    class UU,WW,XX success
    class VV,YY,AAA error
```

## Key Menu Options

- **q**: Quick squash into parent (no interaction needed)
- **i**: Interactive squash (user selects files to squash)
- **c**: Custom destination (user selects target commit)
- **f**: From source commit (user selects both source and target)
- **b**: Into bookmark (user selects bookmark target)

## Command Variations

- **Standard**: `jj squash --into <target_change_id>`
- **Interactive**: `jj squash --interactive --into <target_change_id>`
- **From Source**: `jj squash --from <source_change_id> --into <target_change_id>`
- **Into Bookmark**: `jj squash --into <bookmark_name>`

## File Locations

- **Core**: `lua/jj-nvim/jj/squash.lua`
- **Actions**: `lua/jj-nvim/jj/actions.lua:509-516`
- **Command Flow**: `lua/jj-nvim/ui/command_flow.lua:205-241`
- **Action Menu**: `lua/jj-nvim/ui/action_menu.lua:124-128`
- **Keybinding**: `s` key for squash operation