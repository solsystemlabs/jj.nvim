# Split Command Workflow

```mermaid
flowchart TD
    A[User Action] --> B{Action Type}
    
    B -->|Press S on commit| C[Single Commit Split]
    B -->|leader+a action menu| D[Action Menu]
    B -->|Command Flow Interface| E[Command Flow]
    
    %% Single Commit Split Flow
    C --> F[show_split_options_menu]
    F --> G[Split Options Menu]
    G --> H{Select Option}
    
    H -->|i| I[Interactive split]
    H -->|p| J[Parallel split]
    H -->|f| K[Fileset split]
    H -->|a| L[Insert after target]
    H -->|b| M[Insert before target]
    H -->|d| N[Custom destination]
    
    %% Interactive Split (default)
    I --> O[split_commit interactive]
    O --> P[Build jj split command]
    P --> Q[jj split --interactive change_id]
    
    %% Parallel Split
    J --> R[split_commit parallel]
    R --> S[Build jj split command]
    S --> T[jj split --parallel change_id]
    
    %% Fileset Split
    K --> U[Prompt for fileset pattern]
    U --> V{Pattern Provided?}
    V -->|No| W[Cancel operation]
    V -->|Yes| X[split_commit fileset]
    X --> Y[Build jj split command]
    Y --> Z[jj split change_id fileset_pattern]
    
    %% Insert After Target
    L --> AA[Enter target selection mode]
    AA --> BB[Select target commit]
    BB --> CC[split_commit insert-after]
    CC --> DD[Build jj split command]
    DD --> EE[jj split --insert-after target_change_id change_id]
    
    %% Insert Before Target
    M --> FF[Enter target selection mode]
    FF --> GG[Select target commit]
    GG --> HH[split_commit insert-before]
    HH --> II[Build jj split command]
    II --> JJ[jj split --insert-before target_change_id change_id]
    
    %% Custom Destination
    N --> KK[Enter target selection mode]
    KK --> LL[Select destination commit]
    LL --> MM[split_commit destination]
    MM --> NN[Build jj split command]
    NN --> OO[jj split --into target_change_id change_id]
    
    %% Action Menu Flow
    D --> PP{Menu Selection}
    PP -->|Single Selection| QQ[Split commit S]
    QQ --> F
    
    %% Command Flow Interface
    E --> RR[Step 1: Split Method Selection]
    RR --> SS[Step 2: Interactive Target Selection]
    SS --> TT[Step 3: Flag Menu]
    TT --> UU[execute_command]
    
    %% Common Execution Path
    Q --> VV[commands.execute_with_immutable_prompt]
    T --> VV
    Z --> VV
    EE --> VV
    JJ --> VV
    OO --> VV
    UU --> VV
    
    VV --> WW[Execute jj command]
    WW --> XX{Success?}
    
    XX -->|Yes| YY[Show success notification]
    XX -->|No| ZZ[Show error message]
    
    %% Success Path
    YY --> AAA[Refresh log display]
    AAA --> BBB[Update commit graph]
    BBB --> CCC[Show split result info]
    
    %% Error Handling
    ZZ --> DDD[Return to previous state]
    W --> DDD
    
    %% Validation
    O --> EEE{Root Commit?}
    R --> EEE
    X --> EEE
    CC --> EEE
    HH --> EEE
    MM --> EEE
    
    EEE -->|Yes| FFF[Show error - cannot split root]
    EEE -->|No| P
    FFF --> DDD
    
    %% Interactive Terminal Support
    VV --> GGG{Interactive Command?}
    GGG -->|Yes| HHH[Open interactive terminal]
    GGG -->|No| WW
    HHH --> III[User edits in terminal]
    III --> JJJ[Terminal completion]
    JJJ --> WW
    
    %% Styling
    classDef userAction fill:#e1f5fe
    classDef menuAction fill:#f3e5f5
    classDef execution fill:#e8f5e8
    classDef command fill:#fff3e0
    classDef success fill:#e8f5e8
    classDef error fill:#ffebee
    classDef interactive fill:#e1f5fe
    
    class A,B,C,D,E userAction
    class F,G,H,AA,BB,FF,GG,KK,LL,PP,QQ,RR,SS,TT menuAction
    class O,R,X,CC,HH,MM,P,S,Y,DD,II,NN,UU,VV,WW execution
    class Q,T,Z,EE,JJ,OO command
    class YY,AAA,BBB,CCC success
    class ZZ,DDD,FFF error
    class HHH,III,JJJ interactive
```

## Key Menu Options

- **i**: Interactive split (default) - opens editor to select files
- **p**: Parallel split - creates parallel commits instead of sequential
- **f**: Fileset split - split based on file pattern
- **a**: Insert after target - split and insert result after target commit
- **b**: Insert before target - split and insert result before target commit
- **d**: Custom destination - split and move to specific destination

## Command Variations

- **Interactive**: `jj split --interactive <change_id>`
- **Parallel**: `jj split --parallel <change_id>`
- **Fileset**: `jj split <change_id> <fileset_pattern>`
- **Insert After**: `jj split --insert-after <target_change_id> <change_id>`
- **Insert Before**: `jj split --insert-before <target_change_id> <change_id>`
- **Destination**: `jj split --into <target_change_id> <change_id>`

## Interactive Features

- **Terminal Integration**: Interactive splits open in terminal for file selection
- **Fileset Patterns**: Support for jj fileset syntax for advanced file selection
- **Target Selection**: Visual commit selection for destination operations

## File Locations

- **Core**: `lua/jj-nvim/jj/split.lua`
- **Actions**: `lua/jj-nvim/jj/actions.lua:517-523`
- **Command Flow**: `lua/jj-nvim/ui/command_flow.lua:242-278`
- **Action Menu**: `lua/jj-nvim/ui/action_menu.lua:129-133`
- **Keybinding**: `S` (capital) key for split operation