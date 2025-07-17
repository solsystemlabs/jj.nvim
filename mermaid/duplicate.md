# Duplicate Command Workflow

```mermaid
flowchart TD
    A[User Action] --> B{Action Type}
    
    B -->|Press D on commit| C[Single Commit Duplicate]
    B -->|Select multiple + D| D[Multi-Commit Duplicate]
    B -->|leader+a action menu| E[Action Menu]
    B -->|Command Flow Interface| F[Command Flow]
    
    %% Single Commit Duplicate Flow
    C --> G[show_duplicate_options_menu]
    G --> H[Duplicate Options Menu]
    H --> I{Select Option}
    
    I -->|q| J[Quick duplicate in-place]
    I -->|d| K[Custom destination]
    I -->|a| L[Insert after target]
    I -->|b| M[Insert before target]
    
    %% Quick Duplicate (in-place)
    J --> N[duplicate_commit in-place]
    N --> O[Build jj duplicate command]
    O --> P[jj duplicate change_id]
    
    %% Custom Destination
    K --> Q[Enter target selection mode]
    Q --> R[Select destination commit]
    R --> S[duplicate_commit destination]
    S --> T[Build jj duplicate command]
    T --> U[jj duplicate --destination target_change_id change_id]
    
    %% Insert After Target
    L --> V[Enter target selection mode]
    V --> W[Select target commit]
    W --> X[duplicate_commit insert-after]
    X --> Y[Build jj duplicate command]
    Y --> Z[jj duplicate --insert-after target_change_id change_id]
    
    %% Insert Before Target
    M --> AA[Enter target selection mode]
    AA --> BB[Select target commit]
    BB --> CC[duplicate_commit insert-before]
    CC --> DD[Build jj duplicate command]
    DD --> EE[jj duplicate --insert-before target_change_id change_id]
    
    %% Multi-Commit Duplicate Flow
    D --> FF[Space-bar Multi-Select]
    FF --> GG[show_duplicate_destination_menu]
    GG --> HH[Select destination method]
    HH --> II{Destination Type}
    
    II -->|Quick| JJ[duplicate_multiple_commits in-place]
    II -->|Custom| KK[Enter target selection mode]
    II -->|After| LL[Enter target selection mode]
    II -->|Before| MM[Enter target selection mode]
    
    KK --> NN[Select destination]
    LL --> OO[Select target]
    MM --> PP[Select target]
    
    NN --> QQ[duplicate_multiple_commits destination]
    OO --> RR[duplicate_multiple_commits insert-after]
    PP --> SS[duplicate_multiple_commits insert-before]
    
    %% Action Menu Flow
    E --> TT{Menu Selection}
    TT -->|Single Selection| UU[Duplicate commit D]
    TT -->|Multi Selection| VV[Duplicate selected commits D]
    UU --> G
    VV --> FF
    
    %% Command Flow Interface
    F --> WW[Step 1: Target Selection Type]
    WW --> XX[Step 2: Interactive Target Selection]
    XX --> YY[Step 3: Flag Menu]
    YY --> ZZ[execute_command]
    
    %% Common Execution Path
    P --> AAA[commands.execute_with_immutable_prompt]
    U --> AAA
    Z --> AAA
    EE --> AAA
    ZZ --> AAA
    
    %% Multi-Commit Execution
    JJ --> BBB{Async Mode?}
    QQ --> BBB
    RR --> BBB
    SS --> BBB
    
    BBB -->|Yes| CCC[duplicate_multiple_commits_async]
    BBB -->|No| DDD[Sequential duplicate]
    
    CCC --> EEE[Show progress indicator]
    EEE --> FFF[Process commits in parallel]
    FFF --> GGG[Update progress]
    GGG --> HHH[Complete with results]
    
    DDD --> III[Process commits sequentially]
    III --> JJJ[Execute each duplicate]
    JJJ --> KKK[Collect results]
    
    %% Common Completion
    AAA --> LLL[Execute jj command]
    HHH --> MMM[All operations complete]
    KKK --> MMM
    
    LLL --> NNN{Success?}
    MMM --> OOO{All Success?}
    
    NNN -->|Yes| PPP[Show success notification]
    NNN -->|No| QQQ[Show error message]
    
    OOO -->|Yes| RRR[Show success notification]
    OOO -->|No| SSS[Show partial success message]
    
    %% Success Path
    PPP --> TTT[Refresh log display]
    RRR --> TTT
    TTT --> UUU[Update commit graph]
    UUU --> VVV[Show duplicate result info]
    
    %% Error Handling
    QQQ --> WWW[Return to previous state]
    SSS --> WWW
    
    %% Validation
    N --> XXX{Root Commit?}
    S --> XXX
    X --> XXX
    CC --> XXX
    
    XXX -->|Yes| YYY[Show error - cannot duplicate root]
    XXX -->|No| O
    YYY --> WWW
    
    %% Styling
    classDef userAction fill:#e1f5fe
    classDef menuAction fill:#f3e5f5
    classDef execution fill:#e8f5e8
    classDef command fill:#fff3e0
    classDef success fill:#e8f5e8
    classDef error fill:#ffebee
    classDef async fill:#e1f5fe
    
    class A,B,C,D,E,F userAction
    class G,H,I,Q,R,V,W,AA,BB,FF,GG,HH,II,TT,UU,VV,WW,XX,YY menuAction
    class N,S,X,CC,JJ,QQ,RR,SS,O,T,Y,DD,ZZ,AAA,LLL execution
    class P,U,Z,EE command
    class PPP,RRR,TTT,UUU,VVV success
    class QQQ,SSS,WWW,YYY error
    class CCC,EEE,FFF,GGG,HHH async
```

## Key Menu Options

- **q**: Quick duplicate in-place (creates duplicate at same location)
- **d**: Custom destination (user selects where to place duplicate)
- **a**: Insert after target (place duplicate after selected target)
- **b**: Insert before target (place duplicate before selected target)

## Command Variations

- **In-place**: `jj duplicate <change_id>`
- **Destination**: `jj duplicate --destination <target_change_id> <change_id>`
- **Insert After**: `jj duplicate --insert-after <target_change_id> <change_id>`
- **Insert Before**: `jj duplicate --insert-before <target_change_id> <change_id>`
- **Multiple**: `jj duplicate <change_id1> <change_id2> ...`

## Advanced Features

- **Multi-Commit Support**: Select multiple commits with space bar
- **Async Processing**: Progress indicators for multiple duplicate operations
- **Target Selection**: Visual commit selection for destination operations
- **Batch Operations**: Duplicate multiple commits to same destination

## File Locations

- **Core**: `lua/jj-nvim/jj/duplicate.lua`
- **Actions**: `lua/jj-nvim/jj/actions.lua:524-530`
- **Command Flow**: `lua/jj-nvim/ui/command_flow.lua:279-315`
- **Action Menu**: `lua/jj-nvim/ui/action_menu.lua:134-138, 157-161`
- **Keybinding**: `D` (capital) key for duplicate operation